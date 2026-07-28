//
//  FlightHistoryDebugView.swift
//  FlightMate
//
//  A minimal debug view for verifying that FlightHistoryEngine is
//  correctly recording an ordered timeline from FlightEvents.
//

import SwiftUI

/// Shows `FlightHistoryEngine`'s current (in-progress) flight timeline,
/// plus a summary of previously completed/aborted flights this session.
///
/// Like `TelemetryDebugView`/`FlightContextDebugView`, this exists purely
/// to make an in-progress pipeline observable — it is not the eventual
/// Timeline/Debrief UI, and deliberately has no styling or animation work.
struct FlightHistoryDebugView: View {
    @ObservedObject var flightHistoryEngine: FlightHistoryEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight History Debug")
                .font(.headline)

            if let current = flightHistoryEngine.currentHistory {
                historySummary(current)
                Divider()
                Text("Timeline")
                    .foregroundStyle(.secondary)
                ForEach(current.events, id: \.eventId) { event in
                    timelineRow(event)
                }
            } else {
                Text("No active flight — waiting for an aircraft to load.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Completed This Session (\(flightHistoryEngine.completedHistories.count))")
                .font(.headline)

            if flightHistoryEngine.completedHistories.isEmpty {
                Text("None yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(flightHistoryEngine.completedHistories) { history in
                    HStack {
                        Text(statusDescription(history.status))
                        Text(aircraftDescription(history))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(history.events.count) event(s)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func historySummary(_ history: FlightHistory) -> some View {
        Grid(alignment: .leading, verticalSpacing: 8) {
            GridRow {
                Text("Status")
                    .foregroundStyle(.secondary)
                Text(statusDescription(history.status))
            }
            GridRow {
                Text("Aircraft")
                    .foregroundStyle(.secondary)
                Text(aircraftDescription(history))
            }
            GridRow {
                Text("Departure")
                    .foregroundStyle(.secondary)
                Text(history.departureAirport?.icaoCode ?? "—")
            }
            GridRow {
                Text("Destination")
                    .foregroundStyle(.secondary)
                Text(history.destinationAirport?.icaoCode ?? "—")
            }
            GridRow {
                Text("Duration")
                    .foregroundStyle(.secondary)
                Text(durationDescription(history.durationSeconds))
            }
        }
    }

    private func timelineRow(_ event: FlightEvent) -> some View {
        HStack {
            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(eventDescription(event.type))
        }
        .font(.caption)
    }

    private func statusDescription(_ status: FlightHistoryStatus) -> String {
        switch status {
        case .active: return "Active"
        case .completed: return "Completed"
        case .aborted: return "Aborted"
        }
    }

    private func aircraftDescription(_ history: FlightHistory) -> String {
        history.currentAircraft?.aircraftCode ?? "—"
    }

    private func durationDescription(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private func eventDescription(_ type: FlightEventType) -> String {
        switch type {
        case .aircraftLoaded: return "Aircraft Loaded"
        case .aircraftChanged: return "Aircraft Changed"
        case .enteredTaxi: return "Entered Taxi"
        case .takeoffDetected: return "Takeoff Detected"
        case .enteredCruise: return "Entered Cruise"
        case .enteredDescent: return "Entered Descent"
        case .enteredApproach: return "Entered Approach"
        case .landingDetected: return "Landing Detected"
        case .flightCompleted: return "Flight Completed"
        case .telemetryLost: return "Telemetry Lost"
        case .telemetryRecovered: return "Telemetry Recovered"
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
    FlightHistoryDebugView(flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine))
        .padding()
}
