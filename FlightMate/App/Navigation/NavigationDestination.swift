//
//  NavigationDestination.swift
//  FlightMate
//
//  The single source of truth for FlightMate's top-level navigation --
//  the sidebar simply renders `allCases`; it never hardcodes a list of
//  screens itself.
//

import Foundation

/// One top-level, sidebar-navigable section of the app.
///
/// Adding a future section (AI Copilot, Replay, Flight Recorder,
/// Statistics) is a one-case addition here plus one new branch in
/// `ContentView`'s destination switch -- the sidebar itself
/// (`ContentView`'s `List`) needs no changes at all, since it renders
/// `NavigationDestination.allCases` generically.
enum NavigationDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case movingMap
    case flightHistory
    case airports
    case aircraft
    case settings

    var id: String { rawValue }

    /// Sidebar label.
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .movingMap: return "Moving Map"
        case .flightHistory: return "Flight History"
        case .airports: return "Airports"
        case .aircraft: return "Aircraft"
        case .settings: return "Settings"
        }
    }

    /// SF Symbol shown alongside `title` in the sidebar.
    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .movingMap: return "map"
        case .flightHistory: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .airports: return "building.2"
        case .aircraft: return "airplane"
        case .settings: return "gearshape"
        }
    }
}
