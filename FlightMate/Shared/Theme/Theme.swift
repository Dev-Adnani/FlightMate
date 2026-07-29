//
//  Theme.swift
//  FlightMate
//
//  Centralized design tokens shared across Features. Inspired by calm
//  product UIs (sparse chrome, strong type hierarchy, quiet borders) —
//  adapted for native macOS SwiftUI, not a web clone.
//

import SwiftUI

/// Namespace for FlightMate's design tokens.
enum Theme {
    enum Spacing {
        static let cardGap: CGFloat = 12
        static let cardPadding: CGFloat = 18
        static let contentGap: CGFloat = 12
        static let rowGap: CGFloat = 6
        static let dashboardPadding: CGFloat = 24
        static let sectionGap: CGFloat = 28
        static let listRowVertical: CGFloat = 10
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 12
        static let controlCornerRadius: CGFloat = 8
        static let minCardWidth: CGFloat = 280
        static let mediumBreakpoint: CGFloat = 720
        static let wideBreakpoint: CGFloat = 980
        static let dashboardMaxWidth: CGFloat = 1120
        static let detailMaxWidth: CGFloat = 720
        static let bentoHeroRowMinHeight: CGFloat = 148
        static let bentoBodyRowMinHeight: CGFloat = 180
        static let sidebarIdeal: CGFloat = 220
    }

    enum Typography {
        static let heroMetric = Font.system(size: 32, weight: .semibold, design: .rounded)
        static let title = Font.title2.weight(.semibold)
        static let section = Font.headline.weight(.semibold)
        static let body = Font.body
        static let caption = Font.caption
        static let mono = Font.body.monospacedDigit()
    }

    /// Maps `HealthLevel` onto colors. Always pair with text / SF Symbol.
    static func color(for level: HealthLevel) -> Color {
        switch level {
        case .healthy: return Color(red: 0.18, green: 0.72, blue: 0.42)
        case .warning: return Color(red: 0.92, green: 0.68, blue: 0.12)
        case .critical: return Color(red: 0.92, green: 0.28, blue: 0.28)
        case .informational: return Color(red: 0.28, green: 0.52, blue: 0.96)
        case .neutral: return .secondary
        }
    }
}
