//
//  DashboardView.swift
//  FlightMate
//
//  FlightMate's primary workspace -- the screen a pilot keeps open on a
//  second monitor while flying. A calm, glanceable, bento-grid summary of
//  the current flight; see PROJECT_CONTEXT.md and this milestone's design
//  philosophy for the "answer these questions in under 5 seconds" goal.
//

import SwiftUI

/// Root view for the Dashboard feature.
///
/// Purely a layout: every card renders its own `@Published` model from
/// `viewModel` and contains no business logic of its own. The bento grid
/// (`DashboardBentoGrid`) keeps row heights even and reflows from 3 → 2 →
/// 1 columns as the window resizes.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine,
        aircraftAssetManager: AircraftAssetManaging = AircraftAssetManager()
    ) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                aircraftAssetManager: aircraftAssetManager
            )
        )
    }

    var body: some View {
        ScrollView {
            DashboardBentoGrid(
                aircraft: viewModel.aircraft,
                flightPhase: viewModel.flightPhase,
                navigation: viewModel.navigation,
                telemetry: viewModel.telemetry,
                flightDuration: viewModel.flightDuration,
                recentEvents: viewModel.recentEvents,
                connectionStatus: viewModel.connectionStatus
            )
            .padding(Theme.Spacing.dashboardPadding)
        }
        .navigationTitle("Dashboard")
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
    DashboardView(
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: flightEventEngine,
        flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine)
    )
    .frame(width: 1100, height: 720)
}
