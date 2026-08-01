//
//  DashboardView.swift
//  FlightMate
//
//  FlightMate's primary workspace -- the screen a pilot keeps open on a
//  second monitor while flying. A calm, glanceable, bento-grid summary of
//  the current flight.
//

import SwiftUI

/// Root view for the Dashboard feature.
///
/// Purely a layout: every card renders its own `@Published` model from
/// `viewModel` and contains no business logic of its own.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine,
        aircraftAssetManager: AircraftAssetManaging = AircraftAssetManager(),
        unitPreferenceService: UnitPreferenceService
    ) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                aircraftAssetManager: aircraftAssetManager,
                unitPreferenceService: unitPreferenceService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                dashboardHero
                DashboardBentoGrid(
                    aircraft: viewModel.aircraft,
                    flightPhase: viewModel.flightPhase,
                    navigation: viewModel.navigation,
                    telemetry: viewModel.telemetry,
                    flightDuration: viewModel.flightDuration,
                    recentEvents: viewModel.recentEvents,
                    connectionStatus: viewModel.connectionStatus
                )
            }
            .padding(Theme.Spacing.dashboardPadding)
        }
        .background { Theme.dashboardBackground }
        .navigationTitle("Dashboard")
        .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
    }

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Flight")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var heroSubtitle: String {
        let aircraft = viewModel.aircraft.hasSelection
            ? viewModel.aircraft.aircraftName
            : "No aircraft loaded"
        let phase = viewModel.flightPhase.phaseDisplayName
        return "\(aircraft) · \(phase)"
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
        flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine),
        unitPreferenceService: UnitPreferenceService()
    )
    .frame(width: 1100, height: 720)
}
