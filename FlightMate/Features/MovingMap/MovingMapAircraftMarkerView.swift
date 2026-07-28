//
//  MovingMapAircraftMarkerView.swift
//  FlightMate
//
//  The aircraft's own annotation on the Moving Map.
//

import SwiftUI

/// A simple, heading-oriented aircraft glyph.
///
/// Deliberately minimal -- no aircraft-specific artwork, no animation
/// beyond the implicit rotation SwiftUI already gives
/// `.rotationEffect` -- per this milestone's "no clutter" brief.
struct MovingMapAircraftMarkerView: View {
    /// True heading, in degrees. `location.north.circle.fill` points
    /// north (0°) unrotated, so this maps directly onto
    /// `rotationEffect`.
    let headingDegrees: Double

    var body: some View {
        Image(systemName: "location.north.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .blue)
            .font(.system(size: 26))
            .shadow(radius: 2, y: 1)
            .rotationEffect(.degrees(headingDegrees))
            .accessibilityLabel("Aircraft")
    }
}

#Preview {
    MovingMapAircraftMarkerView(headingDegrees: 45)
        .padding()
}
