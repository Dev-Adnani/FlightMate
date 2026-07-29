//
//  DetailHeader.swift
//  FlightMate
//
//  Large title + optional subtitle for browser detail panes.
//

import SwiftUI

struct DetailHeader: View {
    let title: String
    let subtitle: String?
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(Theme.Typography.title)
                    .foregroundStyle(.primary)
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.color(for: .healthy).opacity(0.15))
                        .foregroundStyle(Theme.color(for: .healthy))
                        .clipShape(Capsule())
                }
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DetailHeader(title: "A320neo", subtitle: "Airbus A320neo · A20N", badge: "Current")
        .padding()
}
