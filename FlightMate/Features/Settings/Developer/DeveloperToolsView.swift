//
//  DeveloperToolsView.swift
//  FlightMate
//
//  Internal diagnostics panel: raw telemetry, flight context/session state,
//  flight analysis, and the event log, all in one place. Replaces the
//  debug views that used to live directly on the Dashboard -- see
//  ConnectionStatusCard for the polished, end-user-facing equivalent.
//
//  This is intentionally *not* styled like the rest of the app: dense,
//  functional, unpolished by design, and never the default user
//  experience. It exists to save time debugging telemetry issues,
//  diagnosing main.mcf parsing problems, and verifying packet formats
//  whenever Aerofly FS 4 updates.
//

import SwiftUI

struct DeveloperToolsView: View {
    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Not intended for end users -- internal diagnostics for verifying telemetry, session parsing, and analysis output.")
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
    DeveloperToolsView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    )
}
