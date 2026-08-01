//
//  FlightHistoryEngineTests.swift
//  FlightMateTests
//
//  Integration-style tests verifying FlightHistoryEngine's Combine wiring
//  actually reacts to live FlightEvents -- following
//  FlightEventEngineTests.swift's exact pattern (real FlightContextEngine +
//  FlightAnalysisEngine + FlightEventEngine over injected fakes, real
//  AeroflySessionService over a synthetic main.mcf fixture).
//
//  Deeper transition-rule coverage (aborting, completing, bounding the
//  completed list, model value semantics) lives in the pure
//  FlightHistoryServiceTests -- these tests only verify that
//  FlightHistoryEngine's subscription to FlightEventEngine.eventPublisher
//  actually delivers and is threaded correctly, mirroring how
//  FlightAnalysisEngineTests/FlightEventEngineTests leave phase-transition-
//  rule coverage to their respective pure-service test suites.
//
//  Every test here reveals its aircraft via a *live* telemetry-driven
//  update fired after `FlightHistoryEngine` is constructed and subscribed
//  -- never one already resolved at `FlightAnalysisEngine`'s own
//  construction time. `eventPublisher` is a bare `PassthroughSubject`
//  (unlike `FlightEventEngine.$analysis`'s `@Published` source), so it
//  never replays anything to a late subscriber: an `aircraftLoaded` that
//  fired synchronously during `FlightEventEngine.init()` (because the
//  aircraft was already resolved beforehand) would be silently missed by
//  a `FlightHistoryEngine` constructed afterward. This is exactly the
//  construction-order requirement documented on `FlightHistoryEngine`
//  itself -- in the real app, `FlightHistoryEngine` is constructed
//  immediately after `FlightEventEngine`, before telemetry/session
//  watching starts, so no aircraft is ever already known at that point.
//

import Combine
import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct FlightHistoryEngineTests {

    @Test func aircraftBecomingKnownLiveStartsAnActiveHistory() async throws {
        let (eventEngine, listener, domainResolver, analysisEngine, flightContextEngine) = makeEventEngine()
        _ = (analysisEngine, flightContextEngine) // keeps the UDP + session pipeline feeding the chain alive for the test's duration
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)
        #expect(historyEngine.currentHistory == nil)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))

        try await waitUntil { historyEngine.currentHistory != nil }
        #expect(historyEngine.currentHistory?.status == .active)
        #expect(historyEngine.currentHistory?.events.map { $0.type } == [.aircraftLoaded])
        #expect(historyEngine.currentHistory?.currentAircraft?.aircraftCode == "a320_neo")
        #expect(historyEngine.completedHistories.isEmpty)
    }

    @Test func aircraftChangeMidFlightAbortsOldHistoryAndStartsANewOneReactingToLiveUpdates() async throws {
        let (eventEngine, listener, domainResolver, analysisEngine, flightContextEngine) = makeEventEngine()
        _ = (analysisEngine, flightContextEngine)
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { historyEngine.currentHistory?.currentAircraft?.aircraftCode == "a320_neo" }

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        // The aircraft-identity debounce (FlightEventDetectionService) only
        // confirms a change once the new code has been observed over two
        // consecutive samples -- the first is just a pending candidate.
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.0,314.1,0.2".utf8))
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.5,314.1,0.2".utf8))

        try await waitUntil { historyEngine.completedHistories.count == 1 }
        #expect(historyEngine.completedHistories.first?.status == .aborted)
        #expect(historyEngine.completedHistories.first?.currentAircraft?.aircraftCode == "a320_neo")
        #expect(historyEngine.currentHistory?.status == .active)
        #expect(historyEngine.currentHistory?.currentAircraft?.aircraftCode == "c172")
    }

    @Test func everyHistoryGetsADistinctId() async throws {
        let (eventEngine, listener, domainResolver, analysisEngine, flightContextEngine) = makeEventEngine()
        _ = (analysisEngine, flightContextEngine)
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { historyEngine.currentHistory != nil }
        let firstId = try #require(historyEngine.currentHistory?.id)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.0,314.1,0.2".utf8))
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.5,314.1,0.2".utf8))
        try await waitUntil { historyEngine.completedHistories.count == 1 }

        let secondId = try #require(historyEngine.currentHistory?.id)
        #expect(firstId != secondId)
        #expect(historyEngine.completedHistories.first?.id == firstId)
    }

    @Test func completedHistoriesAreBoundedWhileReactingToLiveAircraftChanges() async throws {
        let (eventEngine, listener, domainResolver, analysisEngine, flightContextEngine) = makeEventEngine()
        _ = (analysisEngine, flightContextEngine)
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine, maxCompletedHistories: 1)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "aircraft-0")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,10.0,314.1,0.2".utf8))
        try await waitUntil { historyEngine.currentHistory?.currentAircraft?.aircraftCode == "aircraft-0" }

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "aircraft-1")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.5,314.1,0.2".utf8))
        try await waitUntil { historyEngine.completedHistories.count == 1 }

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "aircraft-2")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.0,314.1,0.2".utf8))
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.5,314.1,0.2".utf8))
        try await waitUntil { historyEngine.completedHistories.first?.currentAircraft?.aircraftCode == "aircraft-1" }

        // 2 histories have been aborted in total (aircraft-0, aircraft-1),
        // but the bounded list only ever keeps the most recent `maxCompletedHistories`.
        #expect(historyEngine.completedHistories.count == 1)
        #expect(historyEngine.currentHistory?.currentAircraft?.aircraftCode == "aircraft-2")
    }

    // MARK: - Test helpers

    /// Builds a real `FlightEventEngine` over a real `FlightAnalysisEngine`/
    /// `FlightContextEngine` (UDP + a parsed synthetic `main.mcf`), with an
    /// injected, mutable `DomainResolving` fake that starts out resolving
    /// no aircraft at all, so the very first `aircraftLoaded` always fires
    /// live -- never synchronously during construction -- see this file's
    /// header comment for why that distinction matters here specifically.
    ///
    /// Callers **must** keep the returned `analysisEngine` and
    /// `flightContextEngine` alive for as long as they expect
    /// telemetry-driven updates to keep flowing: `FlightEventEngine` only
    /// subscribes to `analysisEngine.$analysis` -- it never stores a
    /// strong reference to `analysisEngine` itself, so an `analysisEngine`
    /// deallocated by its caller silently orphans that subscription (the
    /// `@Published` storage it feeds from lives inside `analysisEngine`),
    /// and no further events will ever be detected.
    private func makeEventEngine() -> (
        eventEngine: FlightEventEngine,
        listener: UDPListener,
        domainResolver: MutableDomainResolving,
        analysisEngine: FlightAnalysisEngine,
        flightContextEngine: FlightContextEngine
    ) {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf())
        let aeroflySessionService = AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(),
            fileWatcher: FakeAeroflyFileWatching(),
            versionReader: FakeAeroflyVersionReading(),
            readFileContents: { _ in contents.contents }
        )
        aeroflySessionService.start()

        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let flightContextEngine = FlightContextEngine(telemetryService: telemetryService, aeroflySessionService: aeroflySessionService)

        let domainResolver = MutableDomainResolving()

        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: FakeAirportProviding(),
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)

        return (eventEngine, listener, domainResolver, analysisEngine, flightContextEngine)
    }

    private static func resolvedSession(aircraftCode: String) -> ResolvedSession {
        ResolvedSession(
            aircraft: ResolvedAircraft(aircraftCode: aircraftCode, liveryCode: "", aircraft: nil, livery: nil),
            departure: nil,
            destination: nil
        )
    }
}

// MARK: - Test fakes

private final class MutableDomainResolving: DomainResolving {
    var resolvedSessionToReturn = ResolvedSession(aircraft: nil, departure: nil, destination: nil)

    func resolveAircraft(aeroflyCode: String) -> Aircraft? { nil }
    func resolveLivery(aeroflyCode: String, forAircraft aircraftAeroflyCode: String) -> AircraftLivery? { nil }
    func resolve(_ selection: AeroflySession.AircraftSelection) -> ResolvedAircraft {
        ResolvedAircraft(aircraftCode: selection.aeroflyCode, liveryCode: selection.liveryCode, aircraft: nil, livery: nil)
    }

    func resolveAirport(icaoCode: String) -> Airport? { nil }
    func resolveRunway(icaoCode: String, identifier: String) -> Runway? { nil }
    func resolve(_ reference: AeroflySession.RunwayReference) -> ResolvedAirport {
        ResolvedAirport(icaoCode: reference.airportCode, runwayIdentifier: reference.runwayIdentifier, airport: nil, runway: nil, country: nil)
    }

    func resolve(_ session: AeroflySession) -> (resolved: ResolvedSession, report: DomainResolutionReport) {
        (resolvedSessionToReturn, DomainResolutionReport(entries: [], generatedAt: Date()))
    }
}

private final class FakeAirportProviding: AirportProviding {
    func airport(icao: String) -> Airport? { nil }
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { nil }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { [] }
    func searchAirports(query: String, limit: Int) -> [Airport] { [] }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class FakeSessionMetricsTracking: SessionMetricsTracking {
    var metrics = SessionMetrics()
    func record(_ context: FlightContext) {}
}

/// Polls `condition` until it becomes `true` or a short timeout elapses --
/// same rationale/shape as `FlightEventEngineTests.waitUntil`.
@MainActor
private func waitUntil(
    timeout: Duration = .milliseconds(500),
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
