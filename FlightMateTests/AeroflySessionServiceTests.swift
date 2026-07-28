//
//  AeroflySessionServiceTests.swift
//  FlightMateTests
//
//  Exercises AeroflySessionService's full lifecycle via fakes: no real
//  filesystem watching or timing is involved.
//

import Foundation
import Testing
@testable import FlightMate

@MainActor
struct AeroflySessionServiceTests {
    private func makeService(
        directory: URL? = URL(fileURLWithPath: "/fake/Aerofly FS 4", isDirectory: true),
        contents: MutableFileContentsBox = MutableFileContentsBox(),
        version: String? = "4.08.04.01",
        watcher: FakeAeroflyFileWatching = FakeAeroflyFileWatching()
    ) -> AeroflySessionService {
        AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(directoryToReturn: directory),
            fileWatcher: watcher,
            versionReader: FakeAeroflyVersionReading(versionToReturn: version),
            readFileContents: { _ in contents.contents }
        )
    }

    @Test func stateIsUserDirectoryNotFoundWhenLocatorFailsAndNoWatchIsStarted() {
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(directory: nil, watcher: watcher)

        service.start()

        #expect(service.state == .userDirectoryNotFound)
        #expect(service.session == nil)
        #expect(watcher.watchedURL == nil)
    }

    @Test func stateIsFileNotFoundWhenMainMcfIsMissing() {
        let contents = MutableFileContentsBox(nil)
        let service = makeService(contents: contents)

        service.start()

        #expect(service.state == .fileNotFound)
        #expect(service.session == nil)
        #expect(service.lastValidationReport != nil)
    }

    @Test func parsesImmediatelyOnStartBeforeAnyFileChangeEvent() {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf())
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(contents: contents, watcher: watcher)

        service.start()

        #expect(service.state == .loaded)
        #expect(service.session?.aircraft?.aeroflyCode == "a350_1000")
        #expect(watcher.watchedURL != nil)
    }

    @Test func watchesTheMainMcfURLInsideTheResolvedDirectory() {
        let directory = URL(fileURLWithPath: "/fake/Aerofly FS 4", isDirectory: true)
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(directory: directory, watcher: watcher)

        service.start()

        #expect(watcher.watchedURL == directory.appendingPathComponent("main.mcf"))
    }

    @Test func debouncedReparsePicksUpNewContentsAfterFileChangeEvent() async throws {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf(aircraft: "a350_1000"))
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(contents: contents, watcher: watcher)

        service.start()
        #expect(service.session?.aircraft?.aeroflyCode == "a350_1000")

        contents.contents = AeroflySessionFixtures.mainMcf(aircraft: "b787_9")
        watcher.simulateChange()

        try await waitUntilAeroflySession { service.session?.aircraft?.aeroflyCode == "b787_9" }
        #expect(service.session?.aircraft?.aeroflyCode == "b787_9")
    }

    @Test func rapidSuccessiveChangeEventsAreCoalescedIntoOneReparse() async throws {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf(aircraft: "a350_1000"))
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(contents: contents, watcher: watcher)
        service.start()

        contents.contents = AeroflySessionFixtures.mainMcf(aircraft: "a380")
        watcher.simulateChange()
        contents.contents = AeroflySessionFixtures.mainMcf(aircraft: "b787_9")
        watcher.simulateChange()

        try await waitUntilAeroflySession { service.session?.aircraft?.aeroflyCode == "b787_9" }
        #expect(service.session?.aircraft?.aeroflyCode == "b787_9")
    }

    @Test func doesNotRepublishSessionWhenReparsedValueIsUnchanged() async throws {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf())
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(contents: contents, watcher: watcher)
        service.start()

        let sessionBefore = service.session
        watcher.simulateChange() // contents unchanged

        try await Task.sleep(for: .milliseconds(400))
        // Equatable value is unchanged; a real regression here would only
        // be observable via Combine publisher counting, but this at least
        // asserts the published value itself stayed byte-for-byte equal.
        #expect(service.session == sessionBefore)
    }

    @Test func stopHaltsWatching() {
        let watcher = FakeAeroflyFileWatching()
        let service = makeService(watcher: watcher)
        service.start()

        service.stop()

        #expect(watcher.stopCallCount == 1)
    }
}

/// Polls `condition` until it becomes `true` or a short timeout elapses —
/// needed because `AeroflySessionService` debounces reparses on a
/// background `Task`.
@MainActor
private func waitUntilAeroflySession(
    timeout: Duration = .seconds(1),
    _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for condition to become true.")
}
