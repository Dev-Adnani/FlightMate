//
//  UnitSystem.swift
//  FlightMate
//
//  The user's preferred display unit system, independent of the raw SI
//  units telemetry/analysis is always computed and stored in internally.
//

import Foundation

/// Which unit system FlightMate should display values in. Internal
/// computation always stays in aviation units (feet, knots, nautical
/// miles) regardless of this setting -- see `UnitFormatting` for the
/// conversion at the display boundary only.
enum UnitSystem: String, Codable, CaseIterable, Equatable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .imperial: return "Imperial (ft, kt)"
        case .metric: return "Metric (m, km/h)"
        }
    }
}
