//
//  FlightPhase+Display.swift
//  FlightMate
//
//  Presentation-only mapping from FlightPhase (Core/FlightAnalysis) to a
//  human-readable label + SF Symbol. Purely additive -- never modifies
//  FlightPhase itself or the phase-detection logic that produces it.
//

import Foundation

extension FlightPhase {
    /// Short, user-facing label.
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .parked: return "Parked"
        case .taxi: return "Taxi"
        case .takeoff: return "Takeoff"
        case .climb: return "Climb"
        case .cruise: return "Cruise"
        case .descent: return "Descent"
        case .approach: return "Approach"
        case .landing: return "Landing"
        }
    }

    /// A safe, well-established SF Symbol for this phase -- deliberately
    /// simple (no invented cockpit iconography), per this milestone's
    /// "avoid skeuomorphic aviation UI" guidance.
    var systemImage: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .parked: return "parkingsign.circle"
        case .taxi: return "arrow.triangle.turn.up.right.circle"
        case .takeoff: return "airplane.departure"
        case .climb: return "arrow.up.forward.circle"
        case .cruise: return "airplane"
        case .descent: return "arrow.down.forward.circle"
        case .approach, .landing: return "airplane.arrival"
        }
    }
}
