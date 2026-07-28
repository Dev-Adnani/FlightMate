//
//  SettingsSection.swift
//  FlightMate
//
//  The single source of truth for Settings' sidebar sections -- mirrors
//  NavigationDestination's own pattern (an enum + allCases-driven list) so
//  adding a future section is a one-case addition plus one new branch in
//  SettingsView's destination switch.
//

import Foundation

/// One sidebar-navigable section within Settings.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case ai
    case telemetry
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .ai: return "AI"
        case .telemetry: return "Telemetry"
        case .developer: return "Developer"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .ai: return "sparkles"
        case .telemetry: return "antenna.radiowaves.left.and.right"
        case .developer: return "hammer"
        }
    }
}
