//
//  TelemetryCard.swift
//  FlightMate
//
//  Dashboard card: "Is everything healthy?" (live instrument readout).
//

import SwiftUI

/// Shows altitude, ground speed, heading, vertical speed, and connection
/// health -- clean, unit-labeled values, never raw debug fields.
struct TelemetryCard: DashboardCard {
    let model: TelemetryCardModel

    let cardTitle = "Telemetry"
    let cardIcon = "speedometer"

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.contentGap) {
                    metric(label: "Altitude", value: altitudeDisplay)
                    metric(label: "Ground Speed", value: groundSpeedDisplay)
                    metric(label: "Heading", value: headingDisplay)
                    metric(label: "Vertical Speed", value: verticalSpeedDisplay)
                }

                Divider()

                StatusBadge(level: model.connectionHealthLevel, label: model.connectionHealthLabel)
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var altitudeDisplay: String {
        guard let altitude = model.altitudeFeet else { return "—" }
        return "\(Int(altitude.rounded())) ft"
    }

    private var groundSpeedDisplay: String {
        guard let speed = model.groundSpeedKnots else { return "—" }
        return "\(Int(speed.rounded())) kt"
    }

    private var headingDisplay: String {
        guard let heading = model.headingDegrees else { return "—" }
        return String(format: "%03d°", Int(heading.rounded()) % 360)
    }

    private var verticalSpeedDisplay: String {
        guard let verticalSpeed = model.verticalSpeedFeetPerMinute else { return "—" }
        return "\(verticalSpeed >= 0 ? "+" : "")\(Int(verticalSpeed.rounded())) fpm"
    }
}

#Preview {
    TelemetryCard(model: .empty)
        .padding()
        .frame(width: 320)
}
