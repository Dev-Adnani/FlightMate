//
//  AircraftCard.swift
//  FlightMate
//
//  Dashboard card: "What aircraft am I flying?"
//

import SwiftUI

/// Shows the currently selected aircraft, category, and livery.
///
/// Purely presentational -- every field comes straight off
/// `AircraftCardModel`; no lookups, formatting decisions, or resolution
/// logic happen here. The preview image is whatever
/// `AircraftAssetManager` already resolved into `model.asset`.
struct AircraftCard: DashboardCard {
    let model: AircraftCardModel

    let cardTitle = "Aircraft"
    let cardIcon = "airplane"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            HStack(alignment: .top, spacing: 12) {
                AircraftAssetImage(asset: model.asset, isEmphasized: model.hasSelection)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.aircraftName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

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
        .accessibilityLabel("Aircraft: \(model.aircraftName)")
    }
}

#Preview {
    AircraftCard(model: .noSelection)
        .padding()
        .frame(width: 320)
}
