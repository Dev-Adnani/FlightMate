//
//  AircraftCategory.swift
//  FlightMate
//
//  Broad aircraft grouping, derived from Aircraft.tags. Mirrors the
//  classification logic in fboes/aerofly-data's own aircraft picker UI
//  (src/aircraft-functions.js: getSelectOptgroupOptions), including its
//  tag-priority order, so groupings stay consistent with the source data.
//

import Foundation

/// A broad grouping used to organize aircraft in pickers/lists.
enum AircraftCategory: String, CaseIterable {
    case airliner
    case generalAviation
    case military
    case historical
    case helicopter
    case aerobatic
    case glider

    /// Human-readable group label, matching the source data's own labels.
    var displayName: String {
        switch self {
        case .airliner: return "Airliner"
        case .generalAviation: return "General Aviation"
        case .military: return "Military Aircraft"
        case .historical: return "Historical Aircraft"
        case .helicopter: return "Helicopters"
        case .aerobatic: return "Aerobatic Aircraft"
        case .glider: return "Gliders"
        }
    }

    /// Determines the category for a set of tags, using the same
    /// precedence as the source data (checked in this order; the first
    /// match wins).
    init(tags: [String]) {
        if tags.contains("historical") {
            self = .historical
        } else if tags.contains("airliner") {
            self = .airliner
        } else if tags.contains("helicopter") {
            self = .helicopter
        } else if tags.contains("military") {
            self = .military
        } else if tags.contains("glider") {
            self = .glider
        } else if tags.contains("aerobatic") {
            self = .aerobatic
        } else {
            self = .generalAviation
        }
    }
}
