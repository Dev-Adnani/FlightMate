//
//  DispatchSourceAeroflyFileWatcher.swift
//  FlightMate
//
//  Concrete AeroflyFileWatching implementation built on
//  DispatchSourceFileSystemObject — event-driven, no polling.
//

import Foundation
import OSLog

/// Watches a file using `DispatchSourceFileSystemObject`.
///
/// Handles three real-world gotchas explicitly:
/// 1. **Missing file at start**: if Aerofly has never been run,
///    `main.mcf` won't exist yet. This watcher falls back to watching the
///    *parent directory* for the file's creation, then switches to
///    watching the file itself once it appears.
/// 2. **Atomic writes**: some writers replace a file by writing a
///    temporary file and renaming it over the original, which invalidates
///    a file descriptor's association with the original path. On
///    `.delete`/`.rename` events this watcher closes its stale descriptor,
///    retries reopening the path a few times (briefly, non-blocking, via
///    the watcher's own queue), and re-establishes the watch — falling
///    back to watching the parent directory again if the file is still
///    gone after those retries. Critically, it fires `onChange` again
///    *after* a successful reopen so the consumer re-reads the new
///    inode's contents (the earlier callback at the delete/rename moment
///    can race ahead of the replacement file becoming readable).
/// 3. **Directory creation events**: file creation via rename/link does
///    not always surface as a directory `.write` alone, so the directory
///    watch listens for `.write`/`.extend`/`.rename`/`.link`/`.delete`.
///
/// All `DispatchSource` callbacks and mutable state are confined to a
/// single private serial queue, matching `UDPListener`'s concurrency
/// approach elsewhere in this codebase.
nonisolated final class DispatchSourceAeroflyFileWatcher: AeroflyFileWatching, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.flightmate.aeroflyfilewatcher")
    private let fileManager: FileManager

    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var onChange: (() -> Void)?

    /// Number of non-blocking retries attempted when re-opening a file
    /// that briefly disappeared during an atomic write, before falling
    /// back to watching its parent directory instead.
    private static let maxReopenAttempts = 15
    private static let reopenRetryDelay: TimeInterval = 0.05

    /// Events that mean the watched file's bytes may have changed.
    private static let fileEventMask: DispatchSource.FileSystemEvent = [
        .write, .extend, .attrib, .delete, .rename, .link
    ]

    /// Events that mean a file may have appeared/disappeared/changed
    /// inside the parent directory.
    private static let directoryEventMask: DispatchSource.FileSystemEvent = [
        .write, .extend, .attrib, .delete, .rename, .link
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func startWatching(_ url: URL, onChange: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopWatchingLocked()
            self.watchedURL = url
            self.onChange = onChange
            self.beginWatchingLocked()
        }
    }

    func stopWatching() {
        queue.async { [weak self] in
            self?.stopWatchingLocked()
            self?.watchedURL = nil
            self?.onChange = nil
        }
    }

    // MARK: - Must only be called on `queue`

    private func beginWatchingLocked() {
        guard let url = watchedURL else { return }
        if fileManager.fileExists(atPath: url.path) {
            watchFileLocked(url)
        } else {
            watchDirectoryLocked(for: url)
        }
    }

    private func watchFileLocked(_ url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // Race: the file vanished between the fileExists() check and
            // open(). Fall back to watching its parent directory.
            AppLogger.aeroflySession.debug("File watch open failed for \(url.lastPathComponent, privacy: .public); watching parent directory.")
            watchDirectoryLocked(for: url)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: Self.fileEventMask,
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleFileEventLocked(source: source)
        }
        source.setCancelHandler {
            close(descriptor)
        }
        fileSource = source
        source.resume()
    }

    private func handleFileEventLocked(source: DispatchSourceFileSystemObject) {
        let event = source.data
        AppLogger.aeroflySession.debug("main.mcf FS event: \(Self.describe(event), privacy: .public)")

        // Notify immediately — for in-place writes this is sufficient. For
        // delete/rename, the consumer may briefly fail to read; the
        // reestablish path below fires onChange again once the new inode
        // is open.
        onChange?()

        if event.contains(.delete) || event.contains(.rename) {
            reestablishFileWatchLocked(attempt: 0)
        }
    }

    /// Re-opens the watched file after a delete/rename event. Retries a
    /// few times (non-blocking, via `queue.asyncAfter`) before giving up
    /// and watching the parent directory instead.
    private func reestablishFileWatchLocked(attempt: Int) {
        fileSource?.cancel()
        fileSource = nil

        guard let url = watchedURL else { return }

        if fileManager.fileExists(atPath: url.path) {
            watchFileLocked(url)
            // Essential: the onChange fired at the delete/rename moment may
            // have raced ahead of the replacement file. Notify again now
            // that we have a live descriptor on the new inode.
            onChange?()
            return
        }

        guard attempt < Self.maxReopenAttempts else {
            AppLogger.aeroflySession.debug("main.mcf still missing after reopen retries; watching parent directory.")
            watchDirectoryLocked(for: url)
            return
        }

        queue.asyncAfter(deadline: .now() + Self.reopenRetryDelay) { [weak self] in
            self?.reestablishFileWatchLocked(attempt: attempt + 1)
        }
    }

    private func watchDirectoryLocked(for targetURL: URL) {
        // Avoid stacking multiple directory sources if reestablish falls
        // through repeatedly.
        directorySource?.cancel()
        directorySource = nil

        let directoryURL = targetURL.deletingLastPathComponent()
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            AppLogger.aeroflySession.error("Unable to watch Aerofly directory at \(directoryURL.path, privacy: .public)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: Self.directoryEventMask,
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleDirectoryEventLocked(targetURL: targetURL)
        }
        source.setCancelHandler {
            close(descriptor)
        }
        directorySource = source
        source.resume()
    }

    private func handleDirectoryEventLocked(targetURL: URL) {
        guard fileManager.fileExists(atPath: targetURL.path) else { return }

        directorySource?.cancel()
        directorySource = nil
        watchFileLocked(targetURL)
        onChange?()
    }

    private func stopWatchingLocked() {
        fileSource?.cancel()
        fileSource = nil
        directorySource?.cancel()
        directorySource = nil
    }

    private static func describe(_ event: DispatchSource.FileSystemEvent) -> String {
        var parts: [String] = []
        if event.contains(.write) { parts.append("write") }
        if event.contains(.extend) { parts.append("extend") }
        if event.contains(.attrib) { parts.append("attrib") }
        if event.contains(.delete) { parts.append("delete") }
        if event.contains(.rename) { parts.append("rename") }
        if event.contains(.link) { parts.append("link") }
        return parts.isEmpty ? "raw(\(event.rawValue))" : parts.joined(separator: ",")
    }
}
