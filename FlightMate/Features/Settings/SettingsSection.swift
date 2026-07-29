//
//  SettingsSection.swift
//  FlightMate
//
//  Settings sidebar sections. Only surfaces destinations that have real
//  content — no fake "coming soon" preference panes.
//

import Foundation

/// One sidebar-navigable section within Settings.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case about
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .about: return "About"
        case .developer: return "Developer"
        }
    }

    var systemImage: String {
        switch self {
        case .about: return "info.circle"
        case .developer: return "hammer"
        }
    }
}
