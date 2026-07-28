//
//  FlightDurationCard.swift
//  FlightMate
//
//  Dashboard card: "How long have I been flying?"
//

import SwiftUI

/// Shows the current flight's elapsed duration, its status, and how many
/// flights have completed this session.
struct FlightDurationCard: DashboardCard {
    let model: FlightDurationCardModel

    let cardTitle = "Flight Duration"
    let cardIcon = "clock"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                Text(model.durationDisplay ?? "—")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                StatusBadge(level: model.flightStatusLevel, label: model.flightStatusLabel)

                Text("\(model.completedFlightsThisSessionCount) flight(s) completed this session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Flight duration: \(model.durationDisplay ?? "none"), \(model.flightStatusLabel)")
    }
}

#Preview {
    FlightDurationCard(model: .empty)
        .padding()
        .frame(width: 280)
}
