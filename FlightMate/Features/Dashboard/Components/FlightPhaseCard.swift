//
//  FlightPhaseCard.swift
//  FlightMate
//
//  Dashboard card: current phase of flight.
//

import SwiftUI

/// Shows the current flight phase, a plain-language explanation, the
/// aircraft's airborne/on-ground status, and analysis confidence.
struct FlightPhaseCard: DashboardCard {
    let model: FlightPhaseCardModel

    let cardTitle = "Flight Phase"
    let cardIcon = "gauge.with.dots.needle.67percent"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Layout.iconWellCornerRadius, style: .continuous)
                            .fill(Theme.Colors.accent.opacity(0.14))
                            .frame(width: Theme.Spacing.iconWell, height: Theme.Spacing.iconWell)
                        Image(systemName: model.phaseSystemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.phaseDisplayName)
                            .font(.title3.weight(.semibold))
                            .contentTransition(.opacity)
                        Text(model.flightStatusLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if !model.phaseReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.phaseReasons.prefix(3), id: \.self) { reason in
                            Label(reason, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }

                StatusBadge(
                    level: model.confidenceLevel == .high ? .healthy : .warning,
                    label: model.confidenceLevel == .high ? "High Confidence" : "Low Confidence",
                    compact: true
                )
            }
        }
        .accessibilityLabel("Flight phase: \(model.phaseDisplayName), \(model.flightStatusLabel)")
    }
}

#Preview {
    FlightPhaseCard(model: .idle)
        .padding()
        .frame(width: 320, height: 200)
        .background(Theme.dashboardBackground)
}
