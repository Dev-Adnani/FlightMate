//
//  AeroflySessionService.swift
//  FlightMate
//
//  Watches Aerofly's main.mcf (and tm.log for live aircraft) and publishes
//  a parsed AeroflySession — completely independent from TelemetryService/UDP.
//  See FlightContext's doc header for how the two sources are merged and
//  precedence-ordered.
//

import Foundation
import Combine
import OSLog

/// Watches `main.mcf` + `tm.log`, re-parsing whenever either changes, and
/// publishes the result as an `AeroflySession`.
///
/// Aircraft identity prefers the last `done loading model` line in `tm.log`
/// when it disagrees with `main.mcf` (see `AeroflySessionAircraftReconciler`).
///
/// A low-frequency periodic reparse backs up FSEvents so a missed/coalesced
/// write or a "keep last session" after an unreadable atomic replace cannot
/// leave a stale aircraft (e.g. Cessna `c172`) stuck on screen.
///
/// Unlike `TelemetryService`, a missing `main.mcf` is an expected steady
/// state (Aerofly may simply not be running yet), not an error — so
/// `start()`/`stop()` are non-throwing. `start()` parses once immediately
/// (before any file-change event), so aircraft/departure/spawn position
/// are known as early as possible, then begins watching for subsequent
/// changes.
@MainActor
final class AeroflySessionService: ObservableObject {
    @Published private(set) var session: AeroflySession?
    @Published private(set) var state: AeroflySessionState = .notStarted
    @Published private(set) var lastValidationReport: AeroflySessionValidationReport?

    private static let debounceInterval: Duration = .milliseconds(400)
    private static let readRetryCount = 5
    private static let readRetryDelay: Duration = .milliseconds(50)
    private static let mainMcfFileName = "main.mcf"
    private static let tmLogFileName = "tm.log"

    private let directoryLocator: AeroflyUserDirectoryLocating
    private let fileWatcher: AeroflyFileWatching
    private let logFileWatcher: AeroflyFileWatching
    private let versionReader: AeroflyVersionReading
    private let loadedAircraftReader: AeroflyLoadedAircraftReading
    private let readFileContents: (URL) -> String?
    private let now: () -> Date
    private let periodicRefreshInterval: Duration
    private let postFailureRefreshDelay: Duration

    private var mainMcfURL: URL?
    private var userDirectory: URL?
    private var debounceTask: Task<Void, Never>?
    private var periodicRefreshTask: Task<Void, Never>?
    private var postFailureRefreshTask: Task<Void, Never>?

    init(
        directoryLocator: AeroflyUserDirectoryLocating = MacOSAeroflyUserDirectoryLocator(),
        fileWatcher: AeroflyFileWatching = DispatchSourceAeroflyFileWatcher(),
        logFileWatcher: AeroflyFileWatching = DispatchSourceAeroflyFileWatcher(),
        versionReader: AeroflyVersionReading = TmLogAeroflyVersionReader(),
        loadedAircraftReader: AeroflyLoadedAircraftReading = TmLogAeroflyLoadedAircraftReader(),
        readFileContents: @escaping (URL) -> String? = AeroflySessionService.readUncachedUTF8,
        now: @escaping () -> Date = Date.init,
        periodicRefreshInterval: Duration = .seconds(2),
        postFailureRefreshDelay: Duration = .milliseconds(500)
    ) {
        self.directoryLocator = directoryLocator
        self.fileWatcher = fileWatcher
        self.logFileWatcher = logFileWatcher
        self.versionReader = versionReader
        self.loadedAircraftReader = loadedAircraftReader
        self.readFileContents = readFileContents
        self.now = now
        self.periodicRefreshInterval = periodicRefreshInterval
        self.postFailureRefreshDelay = postFailureRefreshDelay
    }

    /// Reads `url` bypassing the kernel's file-data cache so a just-rewritten
    /// `main.mcf` is never served as a stale previous version — a common
    /// cause of "file changed on disk but the app still shows the old
    /// aircraft."
    static func readUncachedUTF8(from url: URL) -> String? {
        do {
            let data = try Data(contentsOf: url, options: [.uncached])
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Resolves Aerofly's user directory, performs one immediate parse
    /// attempt, then begins watching `main.mcf` and `tm.log` plus a
    /// periodic refresh loop.
    func start() {
        stop()

        guard let directory = directoryLocator.locateUserDirectory() else {
            state = .userDirectoryNotFound
            AppLogger.aeroflySession.warning("Aerofly user directory not found; session data unavailable.")
            return
        }

        userDirectory = directory
        let mcfURL = directory.appendingPathComponent(Self.mainMcfFileName)
        let logURL = directory.appendingPathComponent(Self.tmLogFileName)
        mainMcfURL = mcfURL

        parseAndPublish()

        let onChange: () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleDebouncedReparse()
            }
        }
        fileWatcher.startWatching(mcfURL, onChange: onChange)
        logFileWatcher.startWatching(logURL, onChange: onChange)
        startPeriodicRefresh()

        AppLogger.aeroflySession.info(
            "Watching \(mcfURL.path, privacy: .public) and \(Self.tmLogFileName, privacy: .public) for live session updates."
        )
    }

    func stop() {
        fileWatcher.stopWatching()
        logFileWatcher.stopWatching()
        debounceTask?.cancel()
        debounceTask = nil
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
        postFailureRefreshTask?.cancel()
        postFailureRefreshTask = nil
    }

    // MARK: - Reparsing

    private func startPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: self.periodicRefreshInterval)
                guard !Task.isCancelled else { return }
                await self.parseAndPublishWithRetry()
            }
        }
    }

    private func scheduleDebouncedReparse() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.parseAndPublishWithRetry()
        }
    }

    /// After keep-last exhausted on an unreadable read, force another
    /// attempt even if FSEvents stays quiet (atomic replace may have
    /// finished without a second event).
    private func schedulePostFailureRefresh() {
        postFailureRefreshTask?.cancel()
        postFailureRefreshTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.postFailureRefreshDelay)
            guard !Task.isCancelled else { return }
            await self.parseAndPublishWithRetry()
        }
    }

    private func parseAndPublishWithRetry() async {
        guard mainMcfURL != nil, userDirectory != nil else { return }

        for attempt in 0..<Self.readRetryCount {
            if parseAndPublish(allowTransientFailure: attempt < Self.readRetryCount - 1) {
                return
            }
            try? await Task.sleep(for: Self.readRetryDelay)
            guard !Task.isCancelled else { return }
        }
    }

    /// - Returns: `true` if parsing finished (success or hard failure),
    ///   `false` if a transient read failure should be retried.
    @discardableResult
    private func parseAndPublish(allowTransientFailure: Bool = false) -> Bool {
        guard let mcfURL = mainMcfURL, let userDirectory else { return true }

        guard let contents = readFileContents(mcfURL) else {
            if state == .loaded, session != nil {
                if allowTransientFailure {
                    AppLogger.aeroflySession.debug("main.mcf briefly unreadable; keeping last session and retrying.")
                    return false
                }
                AppLogger.aeroflySession.debug("main.mcf unreadable after retries; keeping last session.")
                schedulePostFailureRefresh()
                return true
            }

            publish(session: nil, state: .fileNotFound, report: AeroflySessionValidationReport(
                entries: [AeroflySessionValidationEntry(field: "main.mcf", status: .missing, detail: "file not found at \(mcfURL.path)")],
                generatedAt: now()
            ))
            return true
        }

        let aeroflyVersion = versionReader.readVersion(in: userDirectory)
        let liveAircraft = loadedAircraftReader.readLoadedAircraft(in: userDirectory)

        do {
            let root = try AeroflyMcfParser.parse(contents)
            var (newSession, report) = AeroflySessionMapper.map(root, aeroflyVersion: aeroflyVersion, now: now)
            var entries = report.entries
            AeroflySessionAircraftReconciler.applyLiveAircraft(liveAircraft, to: &newSession, entries: &entries)
            let mergedReport = AeroflySessionValidationReport(entries: entries, generatedAt: report.generatedAt)
            publish(session: newSession, state: .loaded, report: mergedReport)
        } catch {
            let description = error.localizedDescription
            publish(session: nil, state: .parseFailed(description), report: AeroflySessionValidationReport(
                entries: [AeroflySessionValidationEntry(field: "main.mcf", status: .unexpected, detail: description)],
                generatedAt: now()
            ))
        }
        return true
    }

    private func publish(session newSession: AeroflySession?, state newState: AeroflySessionState, report: AeroflySessionValidationReport) {
        let aircraftChanged = session?.aircraft != newSession?.aircraft
        if session != newSession {
            session = newSession
        }
        if state != newState {
            state = newState
        }
        lastValidationReport = report
        log(report, state: newState, aircraftChanged: aircraftChanged)
    }

    private func log(
        _ report: AeroflySessionValidationReport,
        state: AeroflySessionState,
        aircraftChanged: Bool
    ) {
        if aircraftChanged, let aircraft = session?.aircraft {
            AppLogger.aeroflySession.info(
                "Session aircraft updated: \(aircraft.aeroflyCode, privacy: .public) / \(aircraft.liveryCode, privacy: .public)"
            )
        }

        if report.hasWarnings {
            let summary = report.warnings.map { "\($0.field): \($0.status)\($0.detail.map { " (\($0))" } ?? "")" }.joined(separator: "; ")
            AppLogger.aeroflySession.info("Session parsed with \(report.warnings.count) warning(s): \(summary, privacy: .public)")
        } else {
            AppLogger.aeroflySession.debug("Session sources parsed cleanly.")
        }

        if case .parseFailed(let description) = state {
            AppLogger.aeroflySession.error("Failed to parse main.mcf: \(description, privacy: .public)")
        }
    }
}
