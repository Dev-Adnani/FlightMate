//
//  TelemetryCard.swift
//  FlightMate
//
//  Dashboard card: live instrument readout.
//

import SwiftUI

/// Shows altitude, ground speed, heading, vertical speed, and connection
/// health — clean, unit-labeled values, never raw debug fields.
struct TelemetryCard: DashboardCard {
    let model: TelemetryCardModel

    let cardTitle = "Telemetry"
    let cardIcon = "speedometer"

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.cardGap) {
                    MetricReadout(
                        label: "Altitude",
                        value: altitudeDisplay,
                        systemImage: "arrow.up.to.line"
                    )
                    MetricReadout(
                        label: "Ground Speed",
                        value: groundSpeedDisplay,
                        systemImage: "gauge.with.needle"
                    )
                    MetricReadout(
                        label: "Heading",
                        value: headingDisplay,
                        systemImage: "location.north.line"
                    )
                    MetricReadout(
                        label: "Vertical Speed",
                        value: verticalSpeedDisplay,
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                StatusBadge(level: model.connectionHealthLevel, label: model.connectionHealthLabel)
            }
        }
    }

    private var altitudeDisplay: String {
        UnitFormatting.altitude(feet: model.altitudeFeet, system: model.unitSystem)
    }

    private var groundSpeedDisplay: String {
        UnitFormatting.speed(knots: model.groundSpeedKnots, system: model.unitSystem)
    }

    private var headingDisplay: String {
        guard let heading = model.headingDegrees else { return "—" }
        return String(format: "%03d°", Int(heading.rounded()) % 360)
    }

    private var verticalSpeedDisplay: String {
        UnitFormatting.verticalSpeed(feetPerMinute: model.verticalSpeedFeetPerMinute, system: model.unitSystem)
    }
}

#Preview {
    TelemetryCard(model: .empty)
        .padding()
        .frame(width: 360, height: 240)
        .background(Theme.dashboardBackground)
}
