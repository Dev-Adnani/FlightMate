//
//  DashboardView.swift
//  FlightMate
//
//  Primary at-a-glance view of the current flight. UI to be designed.
//

import SwiftUI

/// Root view for the Dashboard feature.
///
/// Currently hosts `TelemetryDebugView`, `FlightContextDebugView`, and
/// `FlightHistoryDebugView` so the telemetry/flight-context/flight-history
/// pipelines are observable while they're being built. Real dashboard
/// content will replace this once there's something more meaningful to
/// show than raw debug data.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine,
        flightHistoryEngine: FlightHistoryEngine
    ) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightHistoryEngine: flightHistoryEngine
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TelemetryDebugView(telemetryService: viewModel.telemetryService)
                Divider()
                FlightContextDebugView(flightContextEngine: viewModel.flightContextEngine)
                Divider()
                FlightHistoryDebugView(flightHistoryEngine: viewModel.flightHistoryEngine)
            }
            .padding()
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
    DashboardView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine)
    )
}
