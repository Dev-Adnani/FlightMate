//
//  FlightPhaseCard.swift
//  FlightMate
//
//  Dashboard card: "What phase of flight am I in?"
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
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                HStack(spacing: 10) {
                    Image(systemName: model.phaseSystemImage)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    Text(model.phaseDisplayName)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text(model.flightStatusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !model.phaseReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(model.phaseReasons, id: \.self) { reason in
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                StatusBadge(
                    level: model.confidenceLevel == .high ? .healthy : .warning,
                    label: model.confidenceLevel == .high ? "High Confidence" : "Low Confidence"
                )
            }
        }
        .accessibilityLabel("Flight phase: \(model.phaseDisplayName), \(model.flightStatusLabel)")
    }
}

#Preview {
    FlightPhaseCard(model: .idle)
        .padding()
        .frame(width: 320)
}
