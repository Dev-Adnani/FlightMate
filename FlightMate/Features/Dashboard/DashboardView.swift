//
//  DashboardView.swift
//  FlightMate
//
//  FlightMate's primary workspace -- the screen a pilot keeps open on a
//  second monitor while flying. A calm, glanceable, card-based summary of
//  the current flight; see PROJECT_CONTEXT.md and this milestone's design
//  philosophy for the "answer these questions in under 5 seconds" goal.
//

import SwiftUI

/// Root view for the Dashboard feature.
///
/// Purely a layout: every card renders its own `@Published` model from
/// `viewModel` and contains no business logic of its own. Uses an adaptive
/// `LazyVGrid` (never fixed pixel positions) so cards reflow naturally as
/// the window resizes, from a single column up to a wide desktop layout.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    private let columns = [GridItem(.adaptive(minimum: Theme.Layout.minCardWidth), spacing: Theme.Spacing.cardGap)]

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine
    ) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.cardGap) {
                AircraftCard(model: viewModel.aircraft)
                FlightPhaseCard(model: viewModel.flightPhase)
                NavigationCard(model: viewModel.navigation)
                TelemetryCard(model: viewModel.telemetry)
                FlightDurationCard(model: viewModel.flightDuration)
                RecentEventsCard(model: viewModel.recentEvents)
                ConnectionStatusCard(model: viewModel.connectionStatus)
            }
            .padding()
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
    .frame(width: 900, height: 700)
}
