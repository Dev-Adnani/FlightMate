//
//  NavigationCard.swift
//  FlightMate
//
//  Dashboard card: "Where am I? Where am I going?"
//

import SwiftUI

/// Shows departure, destination, and nearest airport (via the reusable
/// `AirportCard` atom), plus current heading.
struct NavigationCard: DashboardCard {
    let model: NavigationCardModel

    let cardTitle = "Navigation"
    let cardIcon = "location.north.circle"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                HStack(alignment: .top, spacing: 16) {
                    AirportCard(model: model.departure)
                    AirportCard(model: model.destination)
                    AirportCard(model: model.nearest)
                }

                Divider()

                HStack {
                    Label("Heading", systemImage: "safari")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(headingDisplay)
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private var headingDisplay: String {
        guard let heading = model.headingDegrees else { return "—" }
        return String(format: "%03d°", Int(heading.rounded()) % 360)
    }
}

#Preview {
    NavigationCard(model: .empty)
        .padding()
        .frame(width: 420)
}
