//
//  FlightContextDebugView.swift
//  FlightMate
//
//  A minimal debug view for verifying that XGPS/XATT telemetry is being
//  combined correctly into FlightContext, and that main.mcf session state
//  is parsing as expected. Lives under Settings > Developer -- see
//  DeveloperToolsView -- not on the main Dashboard, which now shows
//  ConnectionStatusCard and NavigationCard instead.
//

import SwiftUI

/// Shows the combined `FlightContext` published by `FlightContextEngine`:
/// position, attitude, ground speed, connection health, session state, and
/// when it was last updated.
///
/// Internal diagnostics only -- not intended for end users. Useful for
/// diagnosing parsing problems and testing new Aerofly versions.
struct FlightContextDebugView: View {
    @ObservedObject var flightContextEngine: FlightContextEngine

    private var context: FlightContext { flightContextEngine.context }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Context")
                .font(.headline)

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Connection Status")
                        .foregroundStyle(.secondary)
                    Text(statusDescription)
                }
                GridRow {
                    Text("Latitude")
                        .foregroundStyle(.secondary)
                    Text(format(context.latitude, unit: "°"))
                }
                GridRow {
                    Text("Longitude")
                        .foregroundStyle(.secondary)
                    Text(format(context.longitude, unit: "°"))
                }
                GridRow {
                    Text("Altitude")
                        .foregroundStyle(.secondary)
                    Text(format(context.altitudeMeters, unit: " m"))
                }
                GridRow {
                    Text("Heading")
                        .foregroundStyle(.secondary)
                    Text(format(context.headingDegreesTrue, unit: "°"))
                }
                GridRow {
                    Text("Ground Speed")
                        .foregroundStyle(.secondary)
                    Text(format(context.groundSpeedMetersPerSecond, unit: " m/s"))
                }
                GridRow {
                    Text("Pitch")
                        .foregroundStyle(.secondary)
                    Text(format(context.pitchDegrees, unit: "°"))
                }
                GridRow {
                    Text("Roll")
                        .foregroundStyle(.secondary)
                    Text(format(context.rollDegrees, unit: "°"))
                }
                GridRow {
                    Text("Last Updated")
                        .foregroundStyle(.secondary)
                    Text(lastUpdatedDescription)
                }
            }

            Divider()

            Text("Session State (main.mcf)")
                .font(.headline)

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Session State")
                        .foregroundStyle(.secondary)
                    Text(sessionStateDescription)
                }
                GridRow {
                    Text("Aircraft")
                        .foregroundStyle(.secondary)
                    Text(aircraftDescription)
                }
                GridRow {
                    Text("Departure")
                        .foregroundStyle(.secondary)
                    Text(runwayDescription(context.aeroflySession?.departure))
                }
                GridRow {
                    Text("Destination")
                        .foregroundStyle(.secondary)
                    Text(runwayDescription(context.aeroflySession?.destination))
                }
                GridRow {
                    Text("On Ground")
                        .foregroundStyle(.secondary)
                    Text(context.aeroflySession?.onGround.map { $0 ? "Yes" : "No" } ?? "—")
                }
                GridRow {
                    Text("Aerofly Version")
                        .foregroundStyle(.secondary)
                    Text(context.aeroflySession?.aeroflyVersion ?? "—")
                }
                GridRow {
                    Text("Validation Warnings")
                        .foregroundStyle(.secondary)
                    Text(validationSummary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var statusDescription: String {
        switch context.connectionStatus {
        case .idle:
            return "Idle"
        case .starting:
            return "Starting…"
        case .listening:
            return "Listening"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private var lastUpdatedDescription: String {
        guard let date = context.lastUpdated else {
            return "—"
        }
        return date.formatted(date: .omitted, time: .standard)
    }

    private func format(_ value: Double?, unit: String) -> String {
        guard let value else {
            return "—"
        }
        return String(format: "%.4f", value) + unit
    }

    private var sessionStateDescription: String {
        switch context.aeroflySessionState {
        case .notStarted:
            return "Not Started"
        case .userDirectoryNotFound:
            return "Aerofly Directory Not Found"
        case .fileNotFound:
            return "main.mcf Not Found"
        case .loaded:
            return "Loaded"
        case .parseFailed(let message):
            return "Parse Failed: \(message)"
        }
    }

    private var aircraftDescription: String {
        guard let aircraft = context.aeroflySession?.aircraft else {
            return "—"
        }
        return "\(aircraft.aeroflyCode) / \(aircraft.liveryCode)"
    }

    private func runwayDescription(_ reference: AeroflySession.RunwayReference?) -> String {
        guard let reference else {
            return "—"
        }
        guard let runway = reference.runwayIdentifier else {
            return reference.airportCode
        }
        return "\(reference.airportCode) / RWY \(runway)"
    }

    private var validationSummary: String {
        guard let report = context.aeroflySessionValidation else {
            return "—"
        }
        return report.hasWarnings ? "\(report.warnings.count) warning(s)" : "None"
    }
}

#Preview {
    FlightContextDebugView(
        flightContextEngine: FlightContextEngine(
            telemetryService: TelemetryService(),
            aeroflySessionService: AeroflySessionService()
        )
    )
}
