//
//  StatusBadge.swift
//  FlightMate
//
//  Reusable SwiftUI components shared across Features live in this folder.
//

import SwiftUI

/// A small colored-dot-plus-label indicator for any `HealthLevel`.
///
/// Color alone never carries the meaning here -- `label` is always shown
/// alongside the dot, so the badge stays legible in high-contrast mode and
/// for colorblind users, per this milestone's accessibility requirements.
struct StatusBadge: View {
    let level: HealthLevel
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.color(for: level))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StatusBadge(level: .healthy, label: "Live")
        StatusBadge(level: .warning, label: "Acquiring…")
        StatusBadge(level: .critical, label: "Not Connected")
        StatusBadge(level: .informational, label: "No Flight Plan")
        StatusBadge(level: .neutral, label: "Unknown")
    }
    .padding()
}
