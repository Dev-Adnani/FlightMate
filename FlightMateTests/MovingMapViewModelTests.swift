//
//  MovingMapViewModelTests.swift
//  FlightMateTests
//
//  Verifies MovingMapViewModel correctly bridges live
//  FlightContext/FlightAnalysis/MapTrailService updates into display
//  state -- following the same real-engines-over-injected-fakes pattern
//  as FlightHistoryEngineTests/MapTrailServiceTests.
//

import Combine
import CoreLocation
import Foundation
import Network
import Testing
@testable import FlightMate

// `.serialized`: see MapTrailServiceTests's header comment for why these
// MainActor-heavy, full-engine-chain tests are run serially within the
// suite rather than left to Swift Testing's default parallelism.
@Suite(.serialized)
@MainActor
struct MovingMapViewModelTests {

    @Test func aircraftPositionAndHeadingReflectLiveTelemetry() async throws {
        let engines = makeEngines()
        // Throttling has its own dedicated test below -- disable it here
        // (interval 0) so this test only verifies the passthrough mapping
        // itself, independent of timing. Without this, the synchronous
        // "free" observation `MovingMapViewModel` takes at construction
        // (of the session's already-known parked position, before any
        // telemetry-driven update) would consume the default throttle
        // window and could suppress the packets sent below.
        let viewModel = MovingMapViewModel(
            flightContextEngine: engines.flightContextEngine,
            flightAnalysisEngine: engines.analysisEngine,
            mapTrailService: MapTrailService(flightContextEngine: engines.flightContextEngine, flightHistoryEngine: engines.historyEngine),
            minimumPositionUpdateInterval: 0
        )

        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        engines.listener.onPacketReceived?(Data("XATTAerofly FS 4,314.1,-0.23,0.29".utf8))

        try await waitUntil { viewModel.aircraftCoordinate?.latitude == 19.0818 && viewModel.aircraftHeadingDegrees != nil }

        #expect(viewModel.aircraftCoordinate?.latitude == 19.0818)
        #expect(viewModel.aircraftCoordinate?.longitude == 72.8754)
        #expect(viewModel.aircraftHeadingDegrees == 314.1)
    }

    @Test func positionUpdatesAreThrottledByMinimumInterval() async throws {
        let engines = makeEngines()
        let clockBox = MutableClockBox(Date(timeIntervalSinceReferenceDate: 0))
        let viewModel = MovingMapViewModel(
            flightContextEngine: engines.flightContextEngine,
            flightAnalysisEngine: engines.analysisEngine,
            mapTrailService: MapTrailService(flightContextEngine: engines.flightContextEngine, flightHistoryEngine: engines.historyEngine),
            minimumPositionUpdateInterval: 1,
            now: { clockBox.now }
        )

        // `MovingMapViewModel` takes one synchronous "free" observation at
        // construction time (the session's already-known parked position,
        // since `flightContextEngine.$context` replays its current value
        // to a new subscriber immediately). That consumes the very first
        // throttle window at `clockBox.now`'s starting instant -- advance
        // the clock past it before sending this test's own first probe
        // packet, so the throttle behavior being tested here starts from
        // a clean window.
        clockBox.now = clockBox.now.addingTimeInterval(2)
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { viewModel.aircraftCoordinate?.latitude == 19.0818 }

        // Still within the same throttle window -- a second, distinctly
        // different position must not be published yet.
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,80.0000,25.0000,11.0,314.1,0.2".utf8))
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.aircraftCoordinate?.latitude == 19.0818)

        // Once the throttle window has elapsed, a new position is
        // published.
        clockBox.now = clockBox.now.addingTimeInterval(2)
        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,90.0000,30.0000,11.0,314.1,0.2".utf8))
        try await waitUntil { viewModel.aircraftCoordinate?.latitude == 30.0 }
    }

    @Test func airportAnnotationsDedupNearestAgainstDepartureByICAOCode() async throws {
        let engines = makeEngines()
        let viewModel = makeViewModel(engines: engines)

        let departure = Self.airport(icaoCode: "KSFO", latitude: 37.6188, longitude: -122.375)
        let destination = Self.airport(icaoCode: "KLAX", latitude: 33.9425, longitude: -118.408)

        engines.domainResolver.resolvedSessionToReturn = ResolvedSession(
            aircraft: nil,
            departure: ResolvedAirport(icaoCode: departure.icaoCode, runwayIdentifier: nil, airport: departure, runway: nil, country: nil),
            destination: ResolvedAirport(icaoCode: destination.icaoCode, runwayIdentifier: nil, airport: destination, runway: nil, country: nil)
        )
        // "Nearest" happens to be the same airport as departure -- must
        // not produce a second, duplicate pin.
        engines.airportProvider.nearestAirportToReturn = departure

        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,-122.375,37.6188,11.0,0.0,0.0".utf8))

        try await waitUntil { viewModel.airportAnnotations.count == 2 }

        #expect(viewModel.airportAnnotations.map(\.role) == [.departure, .destination])
        #expect(viewModel.airportAnnotations.map(\.id) == ["KSFO", "KLAX"])
        #expect(viewModel.routeCoordinates?.count == 2)
    }

    @Test func routeCoordinatesRequireBothDepartureAndDestination() async throws {
        let engines = makeEngines()
        let viewModel = makeViewModel(engines: engines)

        let departure = Self.airport(icaoCode: "KSFO", latitude: 37.6188, longitude: -122.375)
        engines.domainResolver.resolvedSessionToReturn = ResolvedSession(
            aircraft: nil,
            departure: ResolvedAirport(icaoCode: departure.icaoCode, runwayIdentifier: nil, airport: departure, runway: nil, country: nil),
            destination: nil
        )

        engines.listener.onPacketReceived?(Data("XGPSAerofly FS 4,-122.375,37.6188,11.0,0.0,0.0".utf8))

        try await waitUntil { !viewModel.airportAnnotations.isEmpty }

        #expect(viewModel.routeCoordinates == nil)
    }

    @Test func selectingTheSameAirportTwiceClearsTheSelection() async throws {
        let engines = makeEngines()
        let viewModel = makeViewModel(engines: engines)
        let airport = Self.airport(icaoCode: "KSFO", latitude: 37.6188, longitude: -122.375)

        viewModel.selectAirport(airport)
        #expect(viewModel.selectedAirport == airport)

        viewModel.selectAirport(airport)
        #expect(viewModel.selectedAirport == nil)
    }

    @Test func clearSelectionAlwaysClearsRegardlessOfWhatWasSelected() async throws {
        let engines = makeEngines()
        let viewModel = makeViewModel(engines: engines)
        let airport = Self.airport(icaoCode: "KSFO", latitude: 37.6188, longitude: -122.375)

        viewModel.selectAirport(airport)
        viewModel.clearSelection()

        #expect(viewModel.selectedAirport == nil)
    }

    // MARK: - Test helpers

    private struct Engines {
        let listener: UDPListener
        let domainResolver: MutableDomainResolving
        let airportProvider: MutableAirportProviding
        let flightContextEngine: FlightContextEngine
        let analysisEngine: FlightAnalysisEngine
        let eventEngine: FlightEventEngine
        let historyEngine: FlightHistoryEngine
    }

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
        let airportProvider = MutableAirportProviding()

        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: airportProvider,
            sessionMetricsTracker: FakeSessionMetricsTracking()
        )
        let eventEngine = FlightEventEngine(flightAnalysisEngine: analysisEngine)
        let historyEngine = FlightHistoryEngine(flightEventEngine: eventEngine)

        return Engines(
            listener: listener,
            domainResolver: domainResolver,
            airportProvider: airportProvider,
            flightContextEngine: flightContextEngine,
            analysisEngine: analysisEngine,
            eventEngine: eventEngine,
            historyEngine: historyEngine
        )
    }

    private func makeViewModel(engines: Engines) -> MovingMapViewModel {
        MovingMapViewModel(
            flightContextEngine: engines.flightContextEngine,
            flightAnalysisEngine: engines.analysisEngine,
            mapTrailService: MapTrailService(flightContextEngine: engines.flightContextEngine, flightHistoryEngine: engines.historyEngine)
        )
    }

    private static func airport(icaoCode: String, latitude: Double, longitude: Double) -> Airport {
        Airport(icaoCode: icaoCode, name: "\(icaoCode) Airport", latitude: latitude, longitude: longitude)
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

private final class MutableAirportProviding: AirportProviding {
    var nearestAirportToReturn: Airport?

    func airport(icao: String) -> Airport? { nil }
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { nearestAirportToReturn }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { [] }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class FakeSessionMetricsTracking: SessionMetricsTracking {
    var metrics = SessionMetrics()
    func record(_ context: FlightContext) {}
}

private final class MutableClockBox {
    var now: Date
    init(_ now: Date) { self.now = now }
}

/// Polls `condition` until it becomes `true` or a timeout elapses --
/// same rationale/shape as `FlightHistoryEngineTests.waitUntil`, with a
/// more generous timeout for the same reason documented on
/// `MapTrailServiceTests.waitUntil`.
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
