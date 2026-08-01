//
//  StatusBadge.swift
//  FlightMate
//
//  Colored status capsule for HealthLevel signals.
//

import SwiftUI

/// A colored-dot-plus-label indicator for any `HealthLevel`.
///
/// Color alone never carries the meaning — `label` is always shown
/// alongside the indicator for accessibility.
struct StatusBadge: View {
    let level: HealthLevel
    let label: String
    var compact: Bool = false

    private var tint: Color { Theme.color(for: level) }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                .shadow(color: tint.opacity(0.55), radius: 3, x: 0, y: 0)
            Text(label)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.14))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
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
        StatusBadge(level: .informational, label: "No Flight Plan", compact: true)
        StatusBadge(level: .neutral, label: "Unknown")
    }
    .padding()
}
