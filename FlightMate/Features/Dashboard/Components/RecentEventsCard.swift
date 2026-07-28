//
//  RecentEventsCard.swift
//  FlightMate
//
//  Dashboard card: "What happened recently?"
//

import SwiftUI

/// Shows the most recent flight events, newest first, each with a
/// severity-colored icon and timestamp. Not a timeline -- just recent
/// activity, per this card's spec.
struct RecentEventsCard: DashboardCard {
    let model: RecentEventsCardModel

    let cardTitle = "Recent Events"
    let cardIcon = "list.bullet.clipboard"

    var body: some View {
        CardContainer(title: cardTitle, systemImage: cardIcon) {
            if model.rows.isEmpty {
                Text("No events yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                    ForEach(model.rows) { row in
                        eventRow(row)
                    }
                }
            }
        }
    }

    private func eventRow(_ row: EventRowModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.systemImage)
                .foregroundStyle(Theme.color(for: row.severityLevel))
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(row.title)
                .font(.subheadline)
            Spacer()
            Text(row.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RecentEventsCard(model: .empty)
        .padding()
        .frame(width: 320)
}
