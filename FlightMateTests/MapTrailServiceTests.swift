//
//  MapTrailServiceTests.swift
//  FlightMateTests
//
//  Integration-style tests verifying MapTrailService's Combine wiring
//  actually reacts to live FlightContext/FlightHistory updates --
//  following FlightHistoryEngineTests.swift's exact pattern (real
//  FlightContextEngine + FlightAnalysisEngine + FlightEventEngine +
//  FlightHistoryEngine over injected fakes, real AeroflySessionService
//  over a synthetic main.mcf fixture).
//
//  Every intermediate engine (`analysisEngine`, `eventEngine`,
//  `historyEngine`, `flightContextEngine`) is returned from
//  `makeEngines()` and kept alive for the whole test body -- an engine
//  only referenced locally inside the factory would be deallocated the
//  moment the factory returns, silently orphaning any Combine
//  subscription that depends on its `@Published` storage staying alive
//  (see `FlightHistoryEngineTests`'s own header comment for the exact
//  bug this guards against).
//

import Combine
import Foundation
import Network
import Testing
@testable import FlightMate

// `.serialized`: each test builds a full production engine chain
// (UDP listener, telemetry, session, analysis, event, history, trail)
// entirely on the MainActor. Letting Swift Testing's default parallel
// execution run these concurrently with each other multiplies MainActor
// contention for no real benefit (the tests are already fast in
// isolation), which was previously causing `waitUntil` timeouts under
// full-suite runs.
@Suite(.serialized)
@MainActor
struct MapTrailServiceTests {

    @Test func noPositionIsRecordedBeforeAnyAircraftIsEverLoaded() async throws {
        let engines = makeEngines()
        let trailService = MapTrailService(
            flightContextEngine: engines.flightContextEngine,
            flightHistoryEngine: engines.historyEngine
        )

        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await Task.sleep(for: .milliseconds(100))

        #expect(trailService.trail.isEmpty)
    }

    @Test func recordsLivePositionsOnceAFlightBecomesActive() async throws {
        let engines = makeEngines()
        let trailService = MapTrailService(
            flightContextEngine: engines.flightContextEngine,
            flightHistoryEngine: engines.historyEngine,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        engines.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { engines.historyEngine.currentHistory != nil }
        try await waitUntil { !trailService.trail.isEmpty }

        // A second position, far enough away that it clears the
        // sampling threshold, should be recorded as a second point.
        // (Wire format is `XGPS<name>,<longitude>,<latitude>,...` -- this
        // packet only moves longitude.)
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.9754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { trailService.trail.count == 2 }

        #expect(trailService.trail.first?.coordinate.longitude == 72.8754)
        #expect(trailService.trail.last?.coordinate.longitude == 72.9754)
    }

    // Deliberately no integration-level "rapid near-duplicate positions
    // aren't double-recorded" test here: that behavior is `GeoTrailRecordingService
    // .shouldRecord`'s responsibility, already covered exhaustively and
    // deterministically by `GeoTrailRecordingServiceTests` (see
    // `pointTooCloseInBothDistanceAndTimeIsNotRecorded` etc.) without any
    // dependency on the full Combine engine chain settling in time. The
    // engine-chain wiring itself is still covered by
    // `recordsLivePositionsOnceAFlightBecomesActive` below.

    @Test func trailResetsWhenAircraftChangesMidFlight() async throws {
        let engines = makeEngines()
        let trailService = MapTrailService(
            flightContextEngine: engines.flightContextEngine,
            flightHistoryEngine: engines.historyEngine,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        engines.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { !trailService.trail.isEmpty }

        // A genuinely new aircraft mid-flight is a session boundary --
        // FlightHistoryEngine aborts the old history and immediately
        // starts a new one (see FlightHistoryServiceTests), and the
        // trail must start over with it. Wait for the whole
        // abort-and-restart chain to fully settle (proven by
        // `completedHistories` growing) before sending a follow-up
        // packet, rather than asserting anything about this exact
        // packet's own fate -- that keeps this test independent of
        // Combine's precise same-tick delivery ordering between
        // `MapTrailService`'s two subscriptions.
        engines.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,10.0000,10.0000,12.0,314.1,0.2".utf8))
        try await waitUntil { engines.historyEngine.completedHistories.count == 1 }

        // Now that the new flight is definitely active, a fresh position
        // must land in what is, by this point, a reset trail.
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,20.0000,20.0000,12.0,314.1,0.2".utf8))
        try await waitUntil { trailService.trail.last?.coordinate.latitude == 20.0 }

        #expect(!trailService.trail.contains { $0.coordinate.latitude == 72.8754 })
    }

    // MARK: - Test helpers

    private struct Engines {
        let listener: UDPListener
        let domainResolver: MutableDomainResolving
        let flightContextEngine: FlightContextEngine
        let analysisEngine: FlightAnalysisEngine
        let eventEngine: FlightEventEngine
        let historyEngine: FlightHistoryEngine
    }

    /// Builds the full, real engine chain (telemetry + session +
    /// analysis + events + history) with an injected, mutable
    /// `DomainResolving` fake that starts out resolving no aircraft at
    /// all -- mirroring `FlightHistoryEngineTests.makeEventEngine()`.
    private func makeEngines() -> Engines {
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
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)

        return Engines(
            listener: listener,
            domainResolver: domainResolver,
            flightContextEngine: flightContextEngine,
            analysisEngine: analysisEngine,
            eventEngine: eventEngine,
            historyEngine: historyEngine
        )
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
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class FakeSessionMetricsTracking: SessionMetricsTracking {
    var metrics = SessionMetrics()
    func record(_ context: FlightContext) {}
}

/// Polls `condition` until it becomes `true` or a timeout elapses --
/// same rationale/shape as `FlightHistoryEngineTests.waitUntil`, just a
/// little more generous given this suite's fuller engine chain.
/// `FlightMate.xctestplan` disables Swift Testing's default
/// cross-suite parallelism for the whole `FlightMateTests` target
/// (see its `parallelizable` setting), which is what makes a modest,
/// fixed timeout reliable here rather than needing to absorb
/// unbounded MainActor contention from unrelated suites.
@MainActor
private func waitUntil(
    timeout: Duration = .seconds(10),
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
