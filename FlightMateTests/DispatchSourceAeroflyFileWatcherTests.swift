//
//  DispatchSourceAeroflyFileWatcherTests.swift
//  FlightMateTests
//
//  Integration tests against the real DispatchSource-based watcher —
//  verifies atomic replace (the pattern Aerofly uses for main.mcf) is
//  detected and that onChange fires again after the new inode is open.
//

import Foundation
import Testing
@testable import FlightMate

@Suite("DispatchSourceAeroflyFileWatcher", .serialized)
struct DispatchSourceAeroflyFileWatcherTests {

    @Test func detectsInPlaceRewrite() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("main.mcf")
        try "version-one".write(to: fileURL, atomically: true, encoding: .utf8)

        let counter = ChangeCounter()
        let watcher = DispatchSourceAeroflyFileWatcher()
        watcher.startWatching(fileURL) { counter.increment() }

        // Give the watcher time to open the file descriptor.
        try await Task.sleep(for: .milliseconds(150))
        let baseline = counter.value

        try "version-two".write(to: fileURL, atomically: false, encoding: .utf8)

        try await waitUntil(timeout: .seconds(2)) { counter.value > baseline }
        #expect(counter.value > baseline)

        watcher.stopWatching()
    }

    @Test func detectsAtomicReplaceAndFiresAfterReopen() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("main.mcf")
        try "version-one".write(to: fileURL, atomically: true, encoding: .utf8)

        let reads = ContentCapture()
        let watcher = DispatchSourceAeroflyFileWatcher()
        watcher.startWatching(fileURL) {
            if let data = try? Data(contentsOf: fileURL, options: [.uncached]),
               let text = String(data: data, encoding: .utf8) {
                reads.append(text)
            }
        }

        try await Task.sleep(for: .milliseconds(150))

        // Atomic replace: write temp, then os.replace — invalidates the
        // old vnode the DispatchSource was watching.
        let temporaryURL = directory.appendingPathComponent("main.mcf.tmp")
        try "version-two-atomic".write(to: temporaryURL, atomically: true, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)

        try await waitUntil(timeout: .seconds(2)) {
            reads.snapshot().contains("version-two-atomic")
        }
        #expect(reads.snapshot().contains("version-two-atomic"))

        watcher.stopWatching()
    }

    @Test func detectsFileAppearingInPreviouslyEmptyDirectory() async throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("main.mcf")
        // Intentionally do NOT create the file yet — watcher should fall
        // back to watching the parent directory.

        let counter = ChangeCounter()
        let watcher = DispatchSourceAeroflyFileWatcher()
        watcher.startWatching(fileURL) { counter.increment() }

        try await Task.sleep(for: .milliseconds(150))
        #expect(counter.value == 0)

        try "appeared".write(to: fileURL, atomically: true, encoding: .utf8)

        try await waitUntil(timeout: .seconds(2)) { counter.value > 0 }
        #expect(counter.value > 0)

        watcher.stopWatching()
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlightMateWatcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntil(
        timeout: Duration,
        _ condition: @Sendable () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Timed out waiting for file-watcher condition.")
    }
}

/// Thread-safe counter — DispatchSource callbacks arrive on a private queue.
private final class ChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }

    func increment() {
        lock.lock(); defer { lock.unlock() }
        _value += 1
    }
}

private final class ContentCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [String] = []

    func append(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        _values.append(value)
    }

    func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return _values
    }
}
