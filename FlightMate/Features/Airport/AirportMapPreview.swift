//
//  AirportMapPreview.swift
//  FlightMate
//
//  Lightweight MapKit preview for an airport detail pane. Prefer MapKit
//  over bundled thumbnails (see PROJECT_CONTEXT).
//

import MapKit
import SwiftUI

struct AirportMapPreview: View {
    let airport: Airport

    var body: some View {
        Map(initialPosition: .region(region)) {
            Marker(airport.icaoCode, coordinate: coordinate)
                .tint(Theme.color(for: .informational))
        }
        .mapStyle(.standard(elevation: .realistic))
        .id(airport.icaoCode)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityLabel("Map of \(airport.name)")
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: airport.latitude, longitude: airport.longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: 12_000, longitudinalMeters: 12_000)
    }
}
