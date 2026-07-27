//
//  TelemetryDebugView.swift
//  FlightMate
//
//  A minimal debug view for verifying that raw UDP telemetry is being
//  received from Aerofly FS 4.
//

import SwiftUI

/// Shows the health of the raw telemetry connection: whether the UDP
/// listener is bound, how many packets have arrived, and when the last one
/// was received.
///
/// This view intentionally shows no *parsed* flight data — telemetry
/// parsing is not implemented yet. It exists purely to make the transport
/// layer observable while it is being built.
struct TelemetryDebugView: View {
    @ObservedObject var telemetryService: TelemetryService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Telemetry Debug")
                .font(.headline)

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Connection Status")
                        .foregroundStyle(.secondary)
                    Text(statusDescription)
                }
                GridRow {
                    Text("Listening Port")
                        .foregroundStyle(.secondary)
                    Text(String(telemetryService.port))
                }
                GridRow {
                    Text("Packets Received")
                        .foregroundStyle(.secondary)
                    Text(String(telemetryService.packetsReceived))
                }
                GridRow {
                    Text("Last Packet")
                        .foregroundStyle(.secondary)
                    Text(lastPacketDescription)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var statusDescription: String {
        switch telemetryService.status {
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

    private var lastPacketDescription: String {
        guard let date = telemetryService.lastPacketDate else {
            return "—"
        }
        return date.formatted(date: .omitted, time: .standard)
    }
}

#Preview {
    TelemetryDebugView(telemetryService: TelemetryService())
}
