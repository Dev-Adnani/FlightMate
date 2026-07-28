//
//  FlightAnalysisEngineTests.swift
//  FlightMateTests
//
//  Integration-style tests verifying FlightAnalysisEngine's Combine wiring
//  actually reacts to live FlightContext changes -- following
//  FlightContextEngineTests.swift's exact pattern (real FlightContextEngine
//  + UDPListener, fake AeroflySessionService, injected fakes for
//  DomainResolving/AirportProviding/SessionMetricsTracking).
//

import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct FlightAnalysisEngineTests {

    private func makeIdleAeroflySessionService() -> AeroflySessionService {
        AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(directoryToReturn: nil),
            fileWatcher: FakeAeroflyFileWatching(),
            versionReader: FakeAeroflyVersionReading(versionToReturn: nil)
        )
    }

    @Test func publishesAnalysisReactingToLiveTelemetry() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let flightContextEngine = FlightContextEngine(telemetryService: telemetryService, aeroflySessionService: makeIdleAeroflySessionService())

        let engine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: FakeDomainResolving(),
            airportProvider: FakeAirportProviding(),
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )

        #expect(engine.analysis.telemetryHealth == .notConnected)

        listener.onStateChange?(.ready)
        try await waitUntil { engine.analysis.telemetryHealth != .notConnected }
        #expect(engine.analysis.telemetryHealth == .acquiring)

        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { engine.analysis.telemetryHealth == .live }
        #expect(engine.analysis.telemetryHealth == .live)
        #expect(engine.analysis.analysisTimestamp != nil)
    }

    @Test func exposesNearestAirportAsAResolvedAirport() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let flightContextEngine = FlightContextEngine(telemetryService: telemetryService, aeroflySessionService: makeIdleAeroflySessionService())

        let airportProvider = FakeAirportProviding()
        airportProvider.nearestAirportToReturn = ReferenceDataFixtures.origin

        let engine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: FakeDomainResolving(),
            airportProvider: airportProvider,
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )

        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { engine.analysis.nearestAirport != nil }

        let nearestAirport = engine.analysis.nearestAirport
        #expect(nearestAirport?.icaoCode == ReferenceDataFixtures.origin.icaoCode)
        #expect(nearestAirport?.airport == ReferenceDataFixtures.origin)
        #expect(nearestAirport?.runwayIdentifier == nil)
        #expect(nearestAirport?.country == nil)
    }

    @Test func resolvesSessionAndFeedsConfidenceWhenAircraftIsKnown() {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf())
        let aeroflySessionService = AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(),
            fileWatcher: FakeAeroflyFileWatching(),
            versionReader: FakeAeroflyVersionReading(),
            readFileContents: { _ in contents.contents }
        )
        aeroflySessionService.start()

        let telemetryService = TelemetryService(listener: UDPListener())
        let flightContextEngine = FlightContextEngine(telemetryService: telemetryService, aeroflySessionService: aeroflySessionService)

        let domainResolver = FakeDomainResolving()
        domainResolver.resolvedSessionToReturn = ResolvedSession(
            // Empty liveryCode -- nothing to resolve there, so this
            // qualifies as fully `.resolved`, not `.partial`.
            aircraft: ResolvedAircraft(aircraftCode: "a350_1000", liveryCode: "", aircraft: ReferenceDataFixtures.a320, livery: nil),
            departure: nil,
            destination: nil
        )

        let engine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: FakeAirportProviding(),
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )

        #expect(domainResolver.resolveSessionCallCount > 0)
        #expect(engine.analysis.confidence.reasons.contains("Aircraft resolved"))
    }

    @Test func recordsEveryContextObservationWithTheSessionMetricsTracker() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let flightContextEngine = FlightContextEngine(telemetryService: telemetryService, aeroflySessionService: makeIdleAeroflySessionService())

        let sessionMetricsTracker = FakeSessionMetricsTracking()
        let engine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: FakeDomainResolving(),
            airportProvider: FakeAirportProviding(),
            sessionMetricsTracker: sessionMetricsTracker
        )
        _ = engine

        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { sessionMetricsTracker.recordedContexts.count > 1 }

        #expect(sessionMetricsTracker.recordedContexts.count >= 2) // initial context + the update
    }
}

// MARK: - Test fakes

private final class FakeDomainResolving: DomainResolving {
    var resolvedSessionToReturn = ResolvedSession(aircraft: nil, departure: nil, destination: nil)
    private(set) var resolveSessionCallCount = 0

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
        resolveSessionCallCount += 1
        return (resolvedSessionToReturn, DomainResolutionReport(entries: [], generatedAt: Date()))
    }
}

private final class FakeAirportProviding: AirportProviding {
    var nearestAirportToReturn: Airport?

    func airport(icao: String) -> Airport? { nil }
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { nearestAirportToReturn }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { nearestAirportToReturn.map { [$0] } ?? [] }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class FakeSessionMetricsTracking: SessionMetricsTracking {
    var metrics = SessionMetrics()
    private(set) var recordedContexts: [FlightContext] = []

    func record(_ context: FlightContext) {
        recordedContexts.append(context)
    }
}

/// Polls `condition` until it becomes `true` or a short timeout elapses --
/// same rationale/shape as `FlightContextEngineTests.waitUntil`.
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
