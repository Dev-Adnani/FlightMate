//
//  FlightEventEngineTests.swift
//  FlightMateTests
//
//  Integration-style tests verifying FlightEventEngine's Combine wiring
//  actually reacts to live FlightAnalysis changes -- following
//  FlightAnalysisEngineTests.swift's exact pattern (real FlightContextEngine
//  + FlightAnalysisEngine over injected fakes, real AeroflySessionService
//  over a synthetic main.mcf fixture).
//

import Combine
import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct FlightEventEngineTests {

    @Test func aircraftAlreadyKnownAtConstructionFiresAircraftLoadedImmediately() {
        let (analysisEngine, _, _, flightContextEngine) = makeAnalysisEngine(aircraftCode: "a320_neo")
        _ = flightContextEngine // keeps the UDP + session pipeline feeding `analysisEngine` alive for the test's duration

        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)

        #expect(eventEngine.events.map { $0.type } == [.aircraftLoaded])
        #expect(eventEngine.events.first?.analysis.resolvedAircraft?.aircraftCode == "a320_neo")
    }

    @Test func publishesEventsReactingToLiveAnalysisUpdates() async throws {
        let (analysisEngine, listener, domainResolver, flightContextEngine) = makeAnalysisEngine(aircraftCode: "a320_neo")
        _ = flightContextEngine // keeps the UDP + session pipeline feeding `analysisEngine` alive for the test's duration
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)
        #expect(eventEngine.events.map { $0.type } == [.aircraftLoaded])

        // A genuinely different aircraft, delivered via the next telemetry-
        // driven FlightContext update (aeroflySession itself is unchanged;
        // only the mocked resolution of it changes), must be detected as
        // a live aircraftChanged event.
        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))

        try await waitUntil { eventEngine.events.map { $0.type } == [.aircraftLoaded, .aircraftChanged] }
        #expect(eventEngine.events.last?.analysis.resolvedAircraft?.aircraftCode == "c172")
    }

    @Test func everyPublishedEventHasADistinctEventId() async throws {
        let (analysisEngine, listener, domainResolver, flightContextEngine) = makeAnalysisEngine(aircraftCode: "a320_neo")
        _ = flightContextEngine // keeps the UDP + session pipeline feeding `analysisEngine` alive for the test's duration
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { eventEngine.events.count == 2 }

        let ids = Set(eventEngine.events.map(\.eventId))
        #expect(ids.count == eventEngine.events.count)
    }

    @Test func eventsAreTrimmedToMaxHistoryWhileEventPublisherDeliversEveryEvent() async throws {
        let (analysisEngine, listener, domainResolver, flightContextEngine) = makeAnalysisEngine(aircraftCode: "a320_neo")
        _ = flightContextEngine // keeps the UDP + session pipeline feeding `analysisEngine` alive for the test's duration
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine, maxHistory: 1)
        #expect(eventEngine.events.map { $0.type } == [.aircraftLoaded]) // 1 event so far, within the bound

        let collector = EventCollector()
        var cancellables = Set<AnyCancellable>()
        eventEngine.eventPublisher
            .sink { collector.record($0) }
            .store(in: &cancellables)

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "c172")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { collector.events.count == 1 }

        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: "a320_neo")
        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,12.0,314.1,0.2".utf8))
        try await waitUntil { collector.events.count == 2 }

        // 3 events have fired in total (aircraftLoaded + 2 aircraftChanged),
        // but the bounded history only ever keeps the most recent `maxHistory`.
        #expect(eventEngine.events.count == 1)
        #expect(eventEngine.events.first?.type == .aircraftChanged)

        // The publisher, unlike `events`, never drops anything regardless
        // of the history bound -- only the 2 events fired after subscribing
        // are checked here, since the very first (aircraftLoaded) fired
        // synchronously during construction, before this test subscribed.
        #expect(collector.events.map { $0.type } == [.aircraftChanged, .aircraftChanged])
    }

    // MARK: - Test helpers

    /// Builds a real `FlightAnalysisEngine` over a real `FlightContextEngine`
    /// (UDP + a parsed synthetic `main.mcf`), with an injected, mutable
    /// `DomainResolving` fake so tests can change the "resolved" aircraft
    /// between telemetry updates without touching real session state.
    ///
    /// `FlightAnalysisEngine` only subscribes to `flightContextEngine.$context`
    /// -- it never stores a strong reference to `flightContextEngine` itself.
    /// Callers **must** keep the returned `flightContextEngine` alive for as
    /// long as they expect telemetry-driven updates to keep flowing, or its
    /// `TelemetryService`/`AeroflySessionService` (and the `Task` consuming
    /// `rawPackets`) get deallocated the moment this factory returns.
    private func makeAnalysisEngine(
        aircraftCode: String
    ) -> (
        analysisEngine: FlightAnalysisEngine,
        listener: UDPListener,
        domainResolver: MutableDomainResolving,
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
        domainResolver.resolvedSessionToReturn = Self.resolvedSession(aircraftCode: aircraftCode)

        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: FakeAirportProviding(),
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )

        return (analysisEngine, listener, domainResolver, flightContextEngine)
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

/// Plain, unsynchronized collector for `FlightEvent`s delivered by
/// `eventPublisher` -- only ever touched from the MainActor test body and
/// the MainActor-isolated `FlightEventEngine` internals, mirroring the
/// existing fakes' (e.g. `FakeSessionMetricsTracking`) lack of explicit
/// locking.
private final class EventCollector {
    private(set) var events: [FlightEvent] = []
    func record(_ event: FlightEvent) { events.append(event) }
}

/// Polls `condition` until it becomes `true` or a short timeout elapses --
/// same rationale/shape as `FlightAnalysisEngineTests.waitUntil`.
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
