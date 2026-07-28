//
//  MovingMapAirportMarkerView.swift
//  FlightMate
//
//  One airport pin's appearance on the Moving Map -- color/glyph vary by
//  role (departure/destination/nearest); selection state grows it
//  slightly, mirroring standard macOS map pin behavior.
//

import SwiftUI

struct MovingMapAirportMarkerView: View {
    let role: MovingMapAirportAnnotation.Role
    let isSelected: Bool

    private var diameter: CGFloat { isSelected ? 30 : 24 }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Image(systemName: symbolName)
                .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
        .shadow(radius: 1.5, y: 1)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(accessibilityLabel)
    }

    private var symbolName: String {
        switch role {
        case .departure: return "airplane.departure"
        case .destination: return "airplane.arrival"
        case .nearest: return "mappin"
        }
    }

    private var color: Color {
        switch role {
        case .departure: return .green
        case .destination: return .orange
        case .nearest: return .secondary
        }
    }

    private var accessibilityLabel: String {
        switch role {
        case .departure: return "Departure airport"
        case .destination: return "Destination airport"
        case .nearest: return "Nearest airport"
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        MovingMapAirportMarkerView(role: .departure, isSelected: false)
        MovingMapAirportMarkerView(role: .destination, isSelected: true)
        MovingMapAirportMarkerView(role: .nearest, isSelected: false)
    }
    .padding()
}
