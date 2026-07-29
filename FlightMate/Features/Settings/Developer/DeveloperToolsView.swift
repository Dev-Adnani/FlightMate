//
//  DeveloperToolsView.swift
//  FlightMate
//
//  Internal diagnostics: telemetry, context, analysis, events, history.
//  Dense and functional by design — not the product UI.
//

import SwiftUI

struct DeveloperToolsView: View {
    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine
    let flightHistoryEngine: FlightHistoryEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Internal diagnostics for verifying telemetry, session parsing, analysis, and history.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()
                TelemetryDebugView(telemetryService: telemetryService)
                Divider()
                FlightContextDebugView(flightContextEngine: flightContextEngine)
                Divider()
                AnalysisInspectorDebugView(flightAnalysisEngine: flightAnalysisEngine)
                Divider()
                EventLogDebugView(flightEventEngine: flightEventEngine)
                Divider()
                FlightHistoryDebugView(flightHistoryEngine: flightHistoryEngine)
            }
            .padding()
        }
        .navigationTitle("Developer")
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
    DeveloperToolsView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: flightEventEngine,
        flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine)
    )
}
