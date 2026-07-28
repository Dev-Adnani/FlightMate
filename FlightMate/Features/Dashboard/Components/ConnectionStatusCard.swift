//
//  ConnectionStatusCard.swift
//  FlightMate
//
//  Dashboard card: "Is everything healthy?" (system connectivity).
//
//  Replaces the previous debug connection views (TelemetryDebugView,
//  FlightContextDebugView) that used to live directly on the Dashboard --
//  those now live under Settings > Developer for diagnostics, and this
//  card is the polished, end-user-facing summary in their place.
//

import SwiftUI

/// Shows telemetry, session, and reference-resolution health, plus one
/// overall system-health indicator.
struct ConnectionStatusCard: DashboardCard {
    let model: ConnectionStatusCardModel

    let cardTitle = "Connection Status"
    let cardIcon = "checkmark.shield"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                StatusBadge(level: model.overallLevel, label: model.overallLabel)
                    .font(.headline)

                Divider()

                statusRow(label: "Telemetry", level: model.telemetryLevel, value: model.telemetryLabel)
                statusRow(label: "Session", level: model.sessionLevel, value: model.sessionLabel)
                statusRow(label: "Reference Data", level: model.referenceResolutionLevel, value: model.referenceResolutionLabel)
            }
        }
        .accessibilityLabel("System health: \(model.overallLabel)")
    }

    private func statusRow(label: String, level: HealthLevel, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            StatusBadge(level: level, label: value)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ConnectionStatusCard(model: .empty)
        .padding()
        .frame(width: 320)
}
