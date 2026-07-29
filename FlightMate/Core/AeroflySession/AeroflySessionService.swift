//
//  AeroflySessionService.swift
//  FlightMate
//
//  Watches Aerofly's main.mcf for changes and publishes a parsed
//  AeroflySession — completely independent from TelemetryService/UDP.
//  See FlightContext's doc header for how the two sources are merged and
//  precedence-ordered.
//

import Foundation
import Combine
import OSLog

/// Watches `main.mcf`, re-parsing it whenever it changes, and publishes
/// the result as an `AeroflySession`.
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

    /// Rapid successive file-change events (common during atomic
    /// write-then-rename saves) are coalesced into a single reparse after
    /// this long a quiet period. Slightly longer than a single disk flush
    /// so a mid-replace read is less likely to see a truncated file.
    private static let debounceInterval: Duration = .milliseconds(400)

    /// How many times to retry a briefly-unreadable `main.mcf` (typical
    /// during an atomic replace) before treating it as genuinely missing.
    private static let readRetryCount = 5
    private static let readRetryDelay: Duration = .milliseconds(50)

    private let directoryLocator: AeroflyUserDirectoryLocating
    private let fileWatcher: AeroflyFileWatching
    private let versionReader: AeroflyVersionReading
    private let readFileContents: (URL) -> String?
    private let now: () -> Date

    private var mainMcfURL: URL?
    private var userDirectory: URL?
    private var debounceTask: Task<Void, Never>?

    init(
        directoryLocator: AeroflyUserDirectoryLocating = MacOSAeroflyUserDirectoryLocator(),
        fileWatcher: AeroflyFileWatching = DispatchSourceAeroflyFileWatcher(),
        versionReader: AeroflyVersionReading = TmLogAeroflyVersionReader(),
        readFileContents: @escaping (URL) -> String? = AeroflySessionService.readUncachedUTF8,
        now: @escaping () -> Date = Date.init
    ) {
        self.directoryLocator = directoryLocator
        self.fileWatcher = fileWatcher
        self.versionReader = versionReader
        self.readFileContents = readFileContents
        self.now = now
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
    /// attempt, then begins watching `main.mcf` for subsequent changes.
    /// Idempotent-ish: calling `start()` again re-resolves everything from
    /// scratch.
    func start() {
        stop()

        guard let directory = directoryLocator.locateUserDirectory() else {
            state = .userDirectoryNotFound
            AppLogger.aeroflySession.warning("Aerofly user directory not found; session data unavailable.")
            return
        }

        userDirectory = directory
        let mcfURL = directory.appendingPathComponent("main.mcf")
        mainMcfURL = mcfURL

        parseAndPublish()

        fileWatcher.startWatching(mcfURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleDebouncedReparse()
            }
        }

        AppLogger.aeroflySession.info("Watching \(mcfURL.path, privacy: .public) for live session updates.")
    }

    /// Stops watching and cancels any pending debounced reparse. Safe to
    /// call even if `start()` was never called.
    func stop() {
        fileWatcher.stopWatching()
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: - Reparsing

    private func scheduleDebouncedReparse() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.parseAndPublishWithRetry()
        }
    }

    /// Retries briefly when `main.mcf` is unreadable mid-replace, instead
    /// of immediately publishing `.fileNotFound` and wiping a good session.
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

    /// - Parameter allowTransientFailure: When `true` and the file is
    ///   briefly unreadable while we already have a `.loaded` session,
    ///   keep the last session and return `false` so the caller can retry.
    /// - Returns: `true` if parsing finished (success or hard failure),
    ///   `false` if a transient read failure should be retried.
    @discardableResult
    private func parseAndPublish(allowTransientFailure: Bool = false) -> Bool {
        guard let mcfURL = mainMcfURL, let userDirectory else { return true }

        guard let contents = readFileContents(mcfURL) else {
            // Mid-replace / briefly locked: never wipe a previously loaded
            // session just because one read failed. Retry while
            // `allowTransientFailure` is true; after retries are exhausted,
            // still keep the last session so the UI doesn't flicker to
            // "No Aircraft" during atomic saves.
            if state == .loaded, session != nil {
                if allowTransientFailure {
                    AppLogger.aeroflySession.debug("main.mcf briefly unreadable; keeping last session and retrying.")
                    return false
                }
                AppLogger.aeroflySession.debug("main.mcf unreadable after retries; keeping last session.")
                return true
            }

            publish(session: nil, state: .fileNotFound, report: AeroflySessionValidationReport(
                entries: [AeroflySessionValidationEntry(field: "main.mcf", status: .missing, detail: "file not found at \(mcfURL.path)")],
                generatedAt: now()
            ))
            return true
        }

        let aeroflyVersion = versionReader.readVersion(in: userDirectory)

        do {
            let root = try AeroflyMcfParser.parse(contents)
            let (newSession, report) = AeroflySessionMapper.map(root, aeroflyVersion: aeroflyVersion, now: now)
            publish(session: newSession, state: .loaded, report: report)
        } catch {
            let description = error.localizedDescription
            publish(session: nil, state: .parseFailed(description), report: AeroflySessionValidationReport(
                entries: [AeroflySessionValidationEntry(field: "main.mcf", status: .unexpected, detail: description)],
                generatedAt: now()
            ))
        }
        return true
    }

    /// Applies "publish only meaningful changes" for `session`/`state`
    /// (Equatable dedupe), while `lastValidationReport` and the log line
    /// are written on every single parse attempt, per the milestone's
    /// validation requirement.
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
            AppLogger.aeroflySession.info("main.mcf parsed with \(report.warnings.count) warning(s): \(summary, privacy: .public)")
        } else {
            AppLogger.aeroflySession.debug("main.mcf parsed cleanly.")
        }

        if case .parseFailed(let description) = state {
            AppLogger.aeroflySession.error("Failed to parse main.mcf: \(description, privacy: .public)")
        }
    }
}
