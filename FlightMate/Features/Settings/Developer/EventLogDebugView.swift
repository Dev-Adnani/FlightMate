//
//  EventLogDebugView.swift
//  FlightMate
//
//  A minimal debug view for verifying that FlightEventEngine is correctly
//  detecting discrete events from FlightAnalysis transitions. Lives under
//  Settings > Developer -- see DeveloperToolsView.
//

import SwiftUI

/// Shows `FlightEventEngine`'s full bounded event history, newest first.
///
/// Internal diagnostics only -- not intended for end users. Complements
/// `RecentEventsCard` (which only shows a handful of recent events for
/// glanceability) with the complete rolling log, for debugging detection
/// logic.
struct EventLogDebugView: View {
    @ObservedObject var flightEventEngine: FlightEventEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Log (\(flightEventEngine.events.count))")
                .font(.headline)

            if flightEventEngine.events.isEmpty {
                Text("No events detected yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(flightEventEngine.events.reversed(), id: \.eventId) { event in
                        row(for: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func row(for event: FlightEvent) -> some View {
        HStack {
            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(event.type.displayName)
            Text(String(describing: event.severity))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    EventLogDebugView(flightEventEngine: FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine))
        .padding()
}
