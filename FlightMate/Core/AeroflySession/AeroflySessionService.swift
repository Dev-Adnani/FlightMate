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
    /// this long a quiet period.
    private static let debounceInterval: Duration = .milliseconds(250)

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
        readFileContents: @escaping (URL) -> String? = { url in try? String(contentsOf: url, encoding: .utf8) },
        now: @escaping () -> Date = Date.init
    ) {
        self.directoryLocator = directoryLocator
        self.fileWatcher = fileWatcher
        self.versionReader = versionReader
        self.readFileContents = readFileContents
        self.now = now
    }

    /// Resolves Aerofly's user directory, performs one immediate parse
    /// attempt, then begins watching `main.mcf` for subsequent changes.
    /// Idempotent-ish: calling `start()` again re-resolves everything from
    /// scratch.
    func start() {
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
            self?.parseAndPublish()
        }
    }

    private func parseAndPublish() {
        guard let mcfURL = mainMcfURL, let userDirectory else { return }

        guard let contents = readFileContents(mcfURL) else {
            publish(session: nil, state: .fileNotFound, report: AeroflySessionValidationReport(
                entries: [AeroflySessionValidationEntry(field: "main.mcf", status: .missing, detail: "file not found at \(mcfURL.path)")],
                generatedAt: now()
            ))
            return
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
    }

    /// Applies "publish only meaningful changes" for `session`/`state`
    /// (Equatable dedupe), while `lastValidationReport` and the log line
    /// are written on every single parse attempt, per the milestone's
    /// validation requirement.
    private func publish(session newSession: AeroflySession?, state newState: AeroflySessionState, report: AeroflySessionValidationReport) {
        if session != newSession {
            session = newSession
        }
        if state != newState {
            state = newState
        }
        lastValidationReport = report
        log(report, state: newState)
    }

    private func log(_ report: AeroflySessionValidationReport, state: AeroflySessionState) {
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
