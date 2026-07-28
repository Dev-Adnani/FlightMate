//
//  MovingMapAirportInfoCard.swift
//  FlightMate
//
//  The small info card shown after tapping an airport annotation on the
//  Moving Map -- read-only, no editing, no route planning, per this
//  milestone's brief.
//

import SwiftUI

struct MovingMapAirportInfoCard: View {
    let airport: Airport
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(airport.icaoCode)
                        .font(.headline)
                    Text(airport.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if airport.municipality != nil || airport.elevationFt != nil {
                Divider()
                    .padding(.vertical, 2)
            }

            if let municipality = airport.municipality {
                Label(municipality, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let elevationFt = airport.elevationFt {
                Label("\(Int(elevationFt)) ft elevation", systemImage: "arrow.up.to.line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 2)
    }
}

#Preview {
    MovingMapAirportInfoCard(
        airport: Airport(
            icaoCode: "KSFO",
            name: "San Francisco International Airport",
            latitude: 37.6188,
            longitude: -122.375,
            elevationFt: 13,
            municipality: "San Francisco"
        ),
        onDismiss: {}
    )
    .padding()
}
