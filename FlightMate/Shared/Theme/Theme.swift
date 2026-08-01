//
//  Theme.swift
//  FlightMate
//
//  Centralized design tokens. Calm aviation companion aesthetic —
//  sky accents, quiet depth, strong type hierarchy. Native macOS SwiftUI.
//

import SwiftUI

/// Namespace for FlightMate's design tokens.
enum Theme {
    enum Spacing {
        static let cardGap: CGFloat = 14
        static let cardPadding: CGFloat = 18
        static let contentGap: CGFloat = 12
        static let rowGap: CGFloat = 6
        static let dashboardPadding: CGFloat = 28
        static let sectionGap: CGFloat = 28
        static let listRowVertical: CGFloat = 10
        static let iconWell: CGFloat = 40
    }

    enum Layout {
        static let cardCornerRadius: CGFloat = 16
        static let controlCornerRadius: CGFloat = 10
        static let iconWellCornerRadius: CGFloat = 12
        static let minCardWidth: CGFloat = 280
        static let mediumBreakpoint: CGFloat = 720
        static let wideBreakpoint: CGFloat = 980
        static let dashboardMaxWidth: CGFloat = 1120
        static let detailMaxWidth: CGFloat = 720
        static let bentoHeroRowMinHeight: CGFloat = 156
        static let bentoBodyRowMinHeight: CGFloat = 188
        static let sidebarIdeal: CGFloat = 232
        static let sidebarMin: CGFloat = 196
    }

    enum Typography {
        static let heroMetric = Font.system(size: 34, weight: .semibold, design: .rounded)
        static let metric = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title = Font.title2.weight(.semibold)
        static let section = Font.headline.weight(.semibold)
        static let body = Font.body
        static let caption = Font.caption
        static let mono = Font.body.monospacedDigit()
        static let monoCaption = Font.caption.monospaced()
    }

    /// Brand / chrome colors. Semantic status stays on `color(for:)`.
    enum Colors {
        /// Instrument-sky accent used for selected chrome and highlights.
        static let accent = Color(red: 0.22, green: 0.58, blue: 0.86)
        /// Cool secondary tint for subtle fills.
        static let accentMuted = Color(red: 0.35, green: 0.55, blue: 0.72)
        static let cardStroke = Color.primary.opacity(0.08)
        static let cardStrokeStrong = Color.primary.opacity(0.12)
        static let iconWellFill = Color.primary.opacity(0.06)
    }

    /// Soft ambient wash behind the dashboard (light + dark safe).
    static var dashboardBackground: some View {
        LinearGradient(
            colors: [
                Colors.accent.opacity(0.10),
                Color(nsColor: .windowBackgroundColor),
                Colors.accentMuted.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Maps `HealthLevel` onto colors. Always pair with text / SF Symbol.
    static func color(for level: HealthLevel) -> Color {
        switch level {
        case .healthy: return Color(red: 0.20, green: 0.74, blue: 0.48)
        case .warning: return Color(red: 0.95, green: 0.70, blue: 0.18)
        case .critical: return Color(red: 0.94, green: 0.32, blue: 0.32)
        case .informational: return Colors.accent
        case .neutral: return .secondary
        }
    }
}
