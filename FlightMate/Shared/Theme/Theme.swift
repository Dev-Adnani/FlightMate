//
//  Theme.swift
//  FlightMate
//
//  Centralized design tokens (colors, spacing, corner radii) shared across
//  Features -- so cards/screens stay visually consistent without every
//  view re-declaring its own spacing/radius constants.
//

import SwiftUI

/// Namespace for FlightMate's design tokens.
enum Theme {
    /// Spacing constants for card-based, adaptive layouts.
    enum Spacing {
        /// Gap between cards in a grid, and between a card's internal
        /// sections.
        static let cardGap: CGFloat = 16
        /// Inner padding applied by `CardContainer`.
        static let cardPadding: CGFloat = 16
        /// Gap between a card's title row and its content.
        static let contentGap: CGFloat = 10
        /// Gap between individual rows of content within a card.
        static let rowGap: CGFloat = 6
    }

    /// Sizing constants for the adaptive dashboard grid.
    enum Layout {
        /// Corner radius applied by `CardContainer`.
        static let cardCornerRadius: CGFloat = 16
        /// Minimum width a card is allowed to shrink to before the grid
        /// wraps it onto its own row -- keeps cards readable at any window
        /// size without ever using a fixed pixel layout.
        static let minCardWidth: CGFloat = 300
    }

    /// Maps the shared `HealthLevel` vocabulary onto concrete colors,
    /// following this milestone's color legend: green = healthy, yellow =
    /// warning, red = critical/disconnected, blue = informational. Colors
    /// are the *only* place meaning is color-coded -- every status is also
    /// always paired with text and/or an SF Symbol so the app remains
    /// legible in high-contrast mode or to colorblind users.
    static func color(for level: HealthLevel) -> Color {
        switch level {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .informational: return .blue
        case .neutral: return .secondary
        }
    }
}
