//
//  ContentView.swift
//  FlightMate
//
//  FlightMate's real application shell -- a sidebar of
//  `NavigationDestination`s driving a full-size detail view per section.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationDestination? = .dashboard

    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine
    let flightHistoryEngine: FlightHistoryEngine
    let mapTrailService: MapTrailService
    let aircraftAssetManager: AircraftAssetManaging
    let aircraftProvider: AircraftProviding
    let airportProvider: AirportProviding
    let procedureProvider: ProcedureProviding

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(NavigationDestination.allCases) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: Theme.Layout.sidebarIdeal)
            .navigationTitle("FlightMate")
        } detail: {
            destinationView(for: selection ?? .dashboard)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                aircraftAssetManager: aircraftAssetManager
            )
        case .movingMap:
            MovingMapView(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                mapTrailService: mapTrailService
            )
        case .flightHistory:
            FlightHistoryView(flightHistoryEngine: flightHistoryEngine)
        case .airports:
            AirportView(
                airportProvider: airportProvider,
                flightAnalysisEngine: flightAnalysisEngine
            )
        case .aircraft:
            AircraftView(
                aircraftProvider: aircraftProvider,
                flightAnalysisEngine: flightAnalysisEngine,
                aircraftAssetManager: aircraftAssetManager
            )
        case .procedures:
            ProceduresView(procedureProvider: procedureProvider)
        case .settings:
            SettingsView(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine
            )
        }
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    let flightHistoryEngine = FlightHistoryEngine(flightEventEngine: flightEventEngine)
    ContentView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: flightEventEngine,
        flightHistoryEngine: flightHistoryEngine,
        mapTrailService: MapTrailService(
            flightContextEngine: flightContextEngine,
            flightHistoryEngine: flightHistoryEngine
        ),
        aircraftAssetManager: AircraftAssetManager(),
        aircraftProvider: AircraftService(),
        airportProvider: AirportService(),
        procedureProvider: ProcedureService()
    )
}
