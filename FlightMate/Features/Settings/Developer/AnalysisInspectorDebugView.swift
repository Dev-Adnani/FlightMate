//
//  AnalysisInspectorDebugView.swift
//  FlightMate
//
//  A minimal debug view for inspecting FlightAnalysisEngine's raw published
//  output field-by-field. Lives under Settings > Developer -- see
//  DeveloperToolsView.
//

import SwiftUI

/// Shows every field of the current `FlightAnalysis`, unformatted.
///
/// Internal diagnostics only -- not intended for end users. Useful for
/// verifying phase-detection/confidence output while developing new
/// aircraft profiles or debugging misclassified flight phases.
struct AnalysisInspectorDebugView: View {
    @ObservedObject var flightAnalysisEngine: FlightAnalysisEngine

    private var analysis: FlightAnalysis { flightAnalysisEngine.analysis }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Inspector")
                .font(.headline)

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Flight Phase")
                        .foregroundStyle(.secondary)
                    Text(String(describing: analysis.flightPhase))
                }
                GridRow {
                    Text("Phase Reasons")
                        .foregroundStyle(.secondary)
                    Text(analysis.phaseReasons.isEmpty ? "—" : analysis.phaseReasons.joined(separator: "; "))
                }
                GridRow {
                    Text("Climbing / Descending / Turning")
                        .foregroundStyle(.secondary)
                    Text("\(analysis.isClimbing) / \(analysis.isDescending) / \(analysis.isTurning)")
                }
                GridRow {
                    Text("Resolved Aircraft")
                        .foregroundStyle(.secondary)
                    Text(analysis.resolvedAircraft.map { "\($0.aircraftCode) (\($0.status))" } ?? "—")
                }
                GridRow {
                    Text("Resolved Departure")
                        .foregroundStyle(.secondary)
                    Text(analysis.resolvedDeparture.map { "\($0.icaoCode) (\($0.status))" } ?? "—")
                }
                GridRow {
                    Text("Resolved Destination")
                        .foregroundStyle(.secondary)
                    Text(analysis.resolvedDestination.map { "\($0.icaoCode) (\($0.status))" } ?? "—")
                }
                GridRow {
                    Text("Vertical Speed")
                        .foregroundStyle(.secondary)
                    Text(analysis.estimatedVerticalSpeedFeetPerMinute.map { "\($0) fpm" } ?? "—")
                }
                GridRow {
                    Text("Ground Track")
                        .foregroundStyle(.secondary)
                    Text(analysis.estimatedGroundTrackDegreesTrue.map { "\($0)°" } ?? "—")
                }
                GridRow {
                    Text("Session Distance")
                        .foregroundStyle(.secondary)
                    Text("\(analysis.estimatedSessionDistanceNauticalMiles) nm")
                }
                GridRow {
                    Text("Session Duration")
                        .foregroundStyle(.secondary)
                    Text(analysis.estimatedSessionDurationSeconds.map { "\($0) s" } ?? "—")
                }
                GridRow {
                    Text("Nearest Airport")
                        .foregroundStyle(.secondary)
                    Text(analysis.nearestAirport.map { "\($0.icaoCode) (\($0.status))" } ?? "—")
                }
                GridRow {
                    Text("Distance to Nearest")
                        .foregroundStyle(.secondary)
                    Text(analysis.distanceToNearestAirportNauticalMiles.map { "\($0) nm" } ?? "—")
                }
                GridRow {
                    Text("Telemetry Health")
                        .foregroundStyle(.secondary)
                    Text(String(describing: analysis.telemetryHealth))
                }
                GridRow {
                    Text("Confidence")
                        .foregroundStyle(.secondary)
                    Text("\(String(describing: analysis.confidence.level)): \(analysis.confidence.reasons.joined(separator: "; "))")
                }
                GridRow {
                    Text("Analysis Timestamp")
                        .foregroundStyle(.secondary)
                    Text(analysis.analysisTimestamp?.formatted(date: .omitted, time: .standard) ?? "—")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    AnalysisInspectorDebugView(flightAnalysisEngine: FlightAnalysisEngine(flightContextEngine: flightContextEngine))
        .padding()
}
