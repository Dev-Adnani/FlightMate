//
//  AircraftCard.swift
//  FlightMate
//
//  Dashboard card: what aircraft am I flying?
//

import SwiftUI

/// Shows the currently selected aircraft, category, and livery.
struct AircraftCard: DashboardCard {
    let model: AircraftCardModel

    let cardTitle = "Aircraft"
    let cardIcon = "airplane"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            HStack(alignment: .top, spacing: 14) {
                AircraftAssetImage(asset: model.asset, isEmphasized: model.hasSelection)
                    .frame(width: 52, height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Layout.iconWellCornerRadius, style: .continuous)
                            .fill(Theme.Colors.accent.opacity(model.hasSelection ? 0.16 : 0.08))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.iconWellCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.aircraftName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    if let code = model.aeroflyCode {
                        Text(code)
                            .font(Theme.Typography.monoCaption)
                            .foregroundStyle(Theme.Colors.accentMuted)
                    }

                    if let category = model.categoryDisplayName {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let livery = model.liveryName {
                        Text(livery)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if model.hasSelection && !model.isResolved {
                        Label("Not in reference data", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Theme.color(for: .warning))
                    }
                }
            }
        }
        .accessibilityLabel(
            model.aeroflyCode.map { "Aircraft: \(model.aircraftName) (\($0))" }
                ?? "Aircraft: \(model.aircraftName)"
        )
    }
}

#Preview {
    AircraftCard(model: .noSelection)
        .padding()
        .frame(width: 320, height: 180)
        .background(Theme.dashboardBackground)
}
