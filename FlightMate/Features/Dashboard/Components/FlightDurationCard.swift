//
//  FlightDurationCard.swift
//  FlightMate
//
//  Dashboard card: takeoff-based flight clock.
//

import SwiftUI

/// Shows the current flight's takeoff-based duration and status.
///
/// While a flight is in progress the duration ticks every second via
/// `TimelineView` -- histories only publish on new `FlightEvent`s, so a
/// static string would freeze for the entire cruise.
struct FlightDurationCard: DashboardCard {
    let model: FlightDurationCardModel

    let cardTitle = "Flight Duration"
    let cardIcon = "clock"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon, accent: Theme.color(for: model.flightStatusLevel)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                durationReadout

                StatusBadge(
                    level: model.flightStatusLevel,
                    label: model.flightStatusLabel,
                    compact: true
                )

                if let secondaryLine = model.secondaryLine {
                    Text(secondaryLine)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityLabel(
            "Flight duration: \(model.durationDisplay() ?? "none"), \(model.flightStatusLabel)"
        )
    }

    @ViewBuilder
    private var durationReadout: some View {
        if model.isLive, model.takeoffTime != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                durationText(model.durationDisplay(at: context.date))
            }
        } else {
            durationText(model.durationDisplay())
        }
    }

    private func durationText(_ value: String?) -> some View {
        Text(value ?? "—")
            .font(Theme.Typography.heroMetric)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
    }
}

#Preview {
    FlightDurationCard(model: .empty)
        .padding()
        .frame(width: 280, height: 180)
        .background(Theme.dashboardBackground)
}
