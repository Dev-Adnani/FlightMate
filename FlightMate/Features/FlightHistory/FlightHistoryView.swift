//
//  FlightHistoryView.swift
//  FlightMate
//
//  Root view for the Flight History feature. UI to be designed.
//

import SwiftUI

/// Root view for the Flight History feature.
///
/// For now this only hosts `FlightHistoryDebugView` (moved here from
/// Dashboard now that Flight History is its own top-level destination) --
/// a real timeline UI is a future milestone.
struct FlightHistoryView: View {
    @StateObject private var viewModel: FlightHistoryViewModel

    init(flightHistoryEngine: FlightHistoryEngine) {
        _viewModel = StateObject(wrappedValue: FlightHistoryViewModel(flightHistoryEngine: flightHistoryEngine))
    }

    var body: some View {
        ScrollView {
            FlightHistoryDebugView(flightHistoryEngine: viewModel.flightHistoryEngine)
                .padding()
        }
        .navigationTitle("Flight History")
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
    FlightHistoryView(flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine))
}
