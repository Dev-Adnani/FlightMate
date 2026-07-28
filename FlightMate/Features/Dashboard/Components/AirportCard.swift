//
//  AirportCard.swift
//  FlightMate
//
//  A small, reusable atom showing one resolved airport role (departure,
//  destination, or nearest). Used three times by NavigationCard today;
//  intentionally independent of it so a future dedicated Airport
//  Information screen can reuse it unchanged.
//

import SwiftUI

/// Renders one `AirportCardModel` -- role label, ICAO/name, and (for
/// `.nearest`) distance.
struct AirportCard: View {
    let model: AirportCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(model.role.label, systemImage: model.role.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let icaoCode = model.icaoCode {
                Text(icaoCode)
                    .font(.title3.weight(.semibold))
                    .monospaced()
                Text(model.airportName ?? (model.isResolved ? "" : "Not in reference data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Not Set")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if let distance = model.distanceNauticalMiles {
                Text("\(Int(distance.rounded())) nm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let icaoCode = model.icaoCode else {
            return "\(model.role.label): not set"
        }
        var label = "\(model.role.label): \(model.airportName ?? icaoCode)"
        if let distance = model.distanceNauticalMiles {
            label += ", \(Int(distance.rounded())) nautical miles"
        }
        return label
    }
}

#Preview {
    HStack(alignment: .top, spacing: 24) {
        AirportCard(model: .from(role: .departure, resolved: nil))
        AirportCard(model: .from(role: .nearest, resolved: nil, distanceNauticalMiles: 12.4))
    }
    .padding()
}
