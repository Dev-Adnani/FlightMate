//
//  FlightHistoryPersistenceServiceTests.swift
//  FlightMateTests
//
//  Integration-style tests verifying FlightHistoryPersistenceService
//  actually writes completed flights via a real (in-memory) SwiftData
//  ModelContainer -- following FlightHistoryEngineTests.swift's exact
//  pipeline setup (real FlightContextEngine + FlightAnalysisEngine +
//  FlightEventEngine + FlightHistoryEngine over injected fakes).
//
//  A minimal 4-sample flight (parked -> taxi -> takeoff -> parked) is
//  driven through synthetic XGPS packets -- deliberately never reaching
//  climb/cruise/descent/approach, which would require real elapsed wall-
//  clock time between samples to compute vertical speed. Reaching
//  ".takeoff" is sufficient to latch `hasBeenAirborneThisSession` and
//  `takeoffTime`, and ".takeoff" is itself a valid predecessor for a
//  direct transition back to ".parked" (see
//  `FlightAnalysisService+Phase.canTransitionToGroundPhase`), which is
//  everything `FlightHistoryPersistenceService` cares about.
//
//  `makePipeline()` returns every intermediate engine (not just
//  `FlightHistoryEngine`), and every test keeps them all alive as locals
//  for its duration -- none of these engines keeps a strong reference to
//  its own upstream dependency (see each engine's own header comment), so
//  letting an intermediate engine fall out of scope silently breaks the
//  whole chain without any error.
//

import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct FlightHistoryPersistenceServiceTests {

    @Test func aCompletedFlightIsPersistedAndReadableViaFetchAll() async throws {
        let pipeline = makePipeline()
        let persistenceService = PersistenceService(isStoredInMemoryOnly: true)
        let sut = FlightHistoryPersistenceService(flightHistoryEngine: pipeline.historyEngine, persistenceService: persistenceService)

        pipeline.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        Self.sendGroundSpeed(0, listener: pipeline.listener)   // -> parked, aircraftLoaded
        Self.sendGroundSpeed(15, listener: pipeline.listener)  // -> taxi
        Self.sendGroundSpeed(60, listener: pipeline.listener)  // -> takeoff (latches takeoffTime)
        Self.sendGroundSpeed(0, listener: pipeline.listener)   // -> parked again -> flightCompleted

        try await waitUntil { !pipeline.historyEngine.completedHistories.isEmpty }
        #expect(pipeline.historyEngine.completedHistories.last?.hasStartedFlight == true)

        try await waitUntil { !sut.fetchAll().isEmpty }
        let persisted = sut.fetchAll()
        #expect(persisted.count == 1)
        #expect(persisted.first?.aircraftCode == "a320_neo")
    }

    @Test func aFlightThatNeverTookOffIsNeverPersisted() async throws {
        let pipeline = makePipeline()
        let persistenceService = PersistenceService(isStoredInMemoryOnly: true)
        let sut = FlightHistoryPersistenceService(flightHistoryEngine: pipeline.historyEngine, persistenceService: persistenceService)

        pipeline.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        Self.sendGroundSpeed(0, listener: pipeline.listener) // -> parked, aircraftLoaded only

        try await waitUntil { pipeline.historyEngine.currentHistory != nil }
        #expect(pipeline.historyEngine.currentHistory?.hasStartedFlight == false)
        #expect(sut.fetchAll().isEmpty)
    }

    @Test func previouslyPersistedFlightsAreVisibleToANewServiceInstanceOverTheSameContainer() async throws {
        let pipeline = makePipeline()
        let persistenceService = PersistenceService(isStoredInMemoryOnly: true)
        let first = FlightHistoryPersistenceService(flightHistoryEngine: pipeline.historyEngine, persistenceService: persistenceService)

        pipeline.domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        Self.sendGroundSpeed(0, listener: pipeline.listener)
        Self.sendGroundSpeed(15, listener: pipeline.listener)
        Self.sendGroundSpeed(60, listener: pipeline.listener)
        Self.sendGroundSpeed(0, listener: pipeline.listener)

        try await waitUntil { !first.fetchAll().isEmpty }

        // A second service instance reading through the same underlying
        // ModelContainer (e.g. after a hypothetical relaunch) must see the
        // same record without needing FlightHistoryEngine to republish.
        let unusedPipeline = makePipeline()
        let second = FlightHistoryPersistenceService(
            flightHistoryEngine: unusedPipeline.historyEngine,
            persistenceService: persistenceService
        )
        #expect(second.fetchAll().count == 1)
        #expect(second.fetchAll().first?.aircraftCode == "c172")
    }

    // MARK: - Pipeline setup

    private struct Pipeline {
        let historyEngine: FlightHistoryEngine
        let eventEngine: FlightEventEngine
        let analysisEngine: FlightAnalysisEngine
        let contextEngine: FlightContextEngine
        let listener: UDPListener
        let domainResolver: MutableDomainResolving
    }

    private func makePipeline() -> Pipeline {
        // A real (fixture-backed) AeroflySessionService is required so a
        // non-nil AeroflySession actually reaches `domainResolver.resolve`
        // -- `directoryToReturn: nil` (no session ever parsed) would leave
        // resolvedAircraft nil for the whole test, no matter what
        // `domainResolver.resolvedSessionToReturn` is set to.
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
        let flightContextEngine = FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: aeroflySessionService
        )
        let domainResolver = MutableDomainResolving()
        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: FakeAirportProvidingForPersistenceTests(),
            sessionMetricsTracker: FakeSessionMetricsTrackingForPersistenceTests()
        )
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)
        return Pipeline(
            historyEngine: historyEngine,
            eventEngine: eventEngine,
            analysisEngine: analysisEngine,
            contextEngine: flightContextEngine,
            listener: listener,
            domainResolver: domainResolver
        )
    }

    private static func resolvedSession(aircraftCode: String) -> ResolvedSession {
        ResolvedSession(
            aircraft: ResolvedAircraft(aircraftCode: aircraftCode, liveryCode: "", aircraft: nil, livery: nil),
            departure: nil,
            destination: nil
        )
    }

    /// Sends a level, constant-altitude XGPS sample at the given ground
    /// speed (knots) -- altitude pinned at 0 throughout so vertical speed
    /// (and therefore isClimbing/isDescending) never becomes true.
    private static func sendGroundSpeed(_ knots: Double, listener: UDPListener) {
        let metersPerSecond = knots / UnitConversion.metersPerSecondToKnots
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,0.0,0.0,\(metersPerSecond)".utf8))
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

private final class FakeAirportProvidingForPersistenceTests: AirportProviding {
    func airport(icao: String) -> Airport? { nil }
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { nil }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { [] }
    func searchAirports(query: String, limit: Int) -> [Airport] { [] }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class FakeSessionMetricsTrackingForPersistenceTests: SessionMetricsTracking {
    var metrics = SessionMetrics()
    func record(_ context: FlightContext) {}
}

/// Polls `condition` until it becomes `true` or a short timeout elapses --
/// same rationale/shape as `FlightHistoryEngineTests.waitUntil`.
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
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(condition())
}
