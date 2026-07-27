//
//  DashboardView.swift
//  FlightMate
//
//  Primary at-a-glance view of the current flight. UI to be designed.
//

import SwiftUI

/// Root view for the Dashboard feature.
///
/// Currently hosts `TelemetryDebugView` and `FlightContextDebugView` so the
/// telemetry and flight-context pipelines are observable while they're
/// being built. Real dashboard content will replace this once there's
/// something more meaningful to show than raw debug data.
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(telemetryService: TelemetryService, flightContextEngine: FlightContextEngine) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TelemetryDebugView(telemetryService: viewModel.telemetryService)
            Divider()
            FlightContextDebugView(flightContextEngine: viewModel.flightContextEngine)
        }
        .padding()
    }
}

#Preview {
    let telemetryService = TelemetryService()
    DashboardView(
        telemetryService: telemetryService,
        flightContextEngine: FlightContextEngine(telemetryService: telemetryService)
    )
}
