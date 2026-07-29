//
//  AircraftViewModelTests.swift
//  FlightMateTests
//

import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct AircraftViewModelTests {
    @Test func followsLiveAircraftIntoDetailSelection() async throws {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf(aircraft: "c172"))
        let watcher = FakeAeroflyFileWatching()
        let sessionService = AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(),
            fileWatcher: watcher,
            logFileWatcher: FakeAeroflyFileWatching(),
            versionReader: FakeAeroflyVersionReading(),
            loadedAircraftReader: FakeAeroflyLoadedAircraftReading(),
            readFileContents: { _ in contents.contents },
            periodicRefreshInterval: .seconds(60)
        )
        sessionService.start()

        let telemetryService = TelemetryService(listener: UDPListener())
        let contextEngine = FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: sessionService
        )
        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: contextEngine,
            domainResolver: FixtureDomainResolving(),
            airportProvider: EmptyAirportProviding(),
            sessionMetricsTracker: NoOpSessionMetricsTracking()
        )

        let aircraftService = AircraftService(
            loader: FakeReferenceDataLoader(
                aircraft: ReferenceDataFixtures.aircraft,
                aircraftLiveries: ReferenceDataFixtures.aircraftLiveries
            )
        )
        let viewModel = AircraftViewModel(
            aircraftProvider: aircraftService,
            flightAnalysisEngine: analysisEngine,
            aircraftAssetManager: AircraftAssetManager(providers: [SystemSymbolAssetProvider()])
        )

        try await waitUntilAircraftVM { viewModel.currentAircraftCode == "c172" }
        #expect(viewModel.selectedAircraftID == "c172")

        contents.contents = AeroflySessionFixtures.mainMcf(aircraft: "a320_neo")
        watcher.simulateChange()

        try await waitUntilAircraftVM {
            viewModel.currentAircraftCode == "a320_neo" && viewModel.selectedAircraftID == "a320_neo"
        }
        #expect(viewModel.selectedAircraftID == "a320_neo")
        #expect(viewModel.currentAircraftCode == "a320_neo")

        sessionService.stop()
    }

    @Test func keepsManualSelectionUntilLiveAircraftChanges() async throws {
        let contents = MutableFileContentsBox(AeroflySessionFixtures.mainMcf(aircraft: "a320_neo"))
        let sessionService = AeroflySessionService(
            directoryLocator: FakeAeroflyUserDirectoryLocator(),
            fileWatcher: FakeAeroflyFileWatching(),
            logFileWatcher: FakeAeroflyFileWatching(),
            versionReader: FakeAeroflyVersionReading(),
            loadedAircraftReader: FakeAeroflyLoadedAircraftReading(),
            readFileContents: { _ in contents.contents },
            periodicRefreshInterval: .seconds(60)
        )
        sessionService.start()

        let telemetryService = TelemetryService(listener: UDPListener())
        let contextEngine = FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: sessionService
        )
        let analysisEngine = FlightAnalysisEngine(
            flightContextEngine: contextEngine,
            domainResolver: FixtureDomainResolving(),
            airportProvider: EmptyAirportProviding(),
            sessionMetricsTracker: NoOpSessionMetricsTracking()
        )
        let aircraftService = AircraftService(
            loader: FakeReferenceDataLoader(
                aircraft: ReferenceDataFixtures.aircraft,
                aircraftLiveries: ReferenceDataFixtures.aircraftLiveries
            )
        )
        let viewModel = AircraftViewModel(
            aircraftProvider: aircraftService,
            flightAnalysisEngine: analysisEngine,
            aircraftAssetManager: AircraftAssetManager(providers: [SystemSymbolAssetProvider()])
        )

        try await waitUntilAircraftVM { viewModel.currentAircraftCode == "a320_neo" }
        viewModel.selectedAircraftID = "c172"
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.selectedAircraftID == "c172")
        #expect(viewModel.currentAircraftCode == "a320_neo")

        sessionService.stop()
    }
}

struct AircraftCardModelTests {
    @Test func includesRawAeroflyCodeFromResolvedAircraft() {
        var analysis = FlightAnalysis.idle
        analysis.resolvedAircraft = ResolvedAircraft(
            aircraftCode: "a320_neo",
            liveryCode: "",
            aircraft: ReferenceDataFixtures.a320,
            livery: nil
        )

        let model = AircraftCardModel.from(
            analysis,
            assetManager: AircraftAssetManager(providers: [SystemSymbolAssetProvider()])
        )

        #expect(model.aeroflyCode == "a320_neo")
        #expect(model.aircraftName == ReferenceDataFixtures.a320.nameFull)
        #expect(model.hasSelection)
    }

    @Test func noSelectionHasNilAeroflyCode() {
        #expect(AircraftCardModel.noSelection.aeroflyCode == nil)
        #expect(!AircraftCardModel.noSelection.hasSelection)
    }
}

// MARK: - Local fakes

private final class FixtureDomainResolving: DomainResolving {
    func resolveAircraft(aeroflyCode: String) -> Aircraft? {
        ReferenceDataFixtures.aircraft.first { $0.aeroflyCode == aeroflyCode }
    }

    func resolveLivery(aeroflyCode: String, forAircraft aircraftAeroflyCode: String) -> AircraftLivery? { nil }

    func resolve(_ selection: AeroflySession.AircraftSelection) -> ResolvedAircraft {
        ResolvedAircraft(
            aircraftCode: selection.aeroflyCode,
            liveryCode: selection.liveryCode,
            aircraft: resolveAircraft(aeroflyCode: selection.aeroflyCode),
            livery: nil
        )
    }

    func resolveAirport(icaoCode: String) -> Airport? { nil }
    func resolveRunway(icaoCode: String, identifier: String) -> Runway? { nil }

    func resolve(_ reference: AeroflySession.RunwayReference) -> ResolvedAirport {
        ResolvedAirport(
            icaoCode: reference.airportCode,
            runwayIdentifier: reference.runwayIdentifier,
            airport: nil,
            runway: nil,
            country: nil
        )
    }

    func resolve(_ session: AeroflySession) -> (resolved: ResolvedSession, report: DomainResolutionReport) {
        let aircraft = session.aircraft.map(resolve)
        return (
            ResolvedSession(aircraft: aircraft, departure: nil, destination: nil),
            DomainResolutionReport(entries: [], generatedAt: Date())
        )
    }
}

private final class EmptyAirportProviding: AirportProviding {
    func airport(icao: String) -> Airport? { nil }
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { nil }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { [] }
    func searchAirports(query: String, limit: Int) -> [Airport] { [] }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { 0 }
}

private final class NoOpSessionMetricsTracking: SessionMetricsTracking {
    var metrics = SessionMetrics()
    func record(_ context: FlightContext) {}
}

@MainActor
private func waitUntilAircraftVM(
    timeout: Duration = .seconds(2),
    _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for AircraftViewModel condition.")
}
