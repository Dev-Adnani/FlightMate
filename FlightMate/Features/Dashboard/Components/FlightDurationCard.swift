//
//  FlightDurationCard.swift
//  FlightMate
//
//  Dashboard card: "How long have I been flying?" (clock starts at takeoff).
//

import SwiftUI

/// Shows the current flight's takeoff-based duration and status.
struct FlightDurationCard: DashboardCard {
    let model: FlightDurationCardModel

    let cardTitle = "Flight Duration"
    let cardIcon = "clock"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                Text(model.durationDisplay ?? "—")
                    .font(Theme.Typography.heroMetric)
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(model.flightStatusLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.color(for: model.flightStatusLevel))

                if let secondaryLine = model.secondaryLine {
                    Text(secondaryLine)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityLabel(
            "Flight duration: \(model.durationDisplay ?? "none"), \(model.flightStatusLabel)"
        )
    }
}

#Preview {
    FlightDurationCard(model: .empty)
        .padding()
        .frame(width: 280)
}
