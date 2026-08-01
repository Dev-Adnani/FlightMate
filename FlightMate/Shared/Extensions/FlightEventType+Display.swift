//
//  FlightEventType+Display.swift
//  FlightMate
//
//  Presentation-only mapping from FlightEventType (Core/FlightEvents) to a
//  human-readable label + SF Symbol. Purely additive -- never modifies
//  FlightEventType or event-detection logic.
//

import Foundation

extension FlightEventType {
    /// Short, user-facing label.
    var displayName: String {
        switch self {
        case .aircraftLoaded: return "Aircraft Loaded"
        case .aircraftChanged: return "Aircraft Changed"
        case .enteredTaxi: return "Entered Taxi"
        case .takeoffDetected: return "Takeoff Detected"
        case .enteredClimb: return "Entered Climb"
        case .enteredCruise: return "Entered Cruise"
        case .enteredDescent: return "Entered Descent"
        case .enteredApproach: return "Entered Approach"
        case .landingDetected: return "Landing Detected"
        case .flightCompleted: return "Flight Completed"
        case .telemetryLost: return "Telemetry Lost"
        case .telemetryRecovered: return "Telemetry Recovered"
        }
    }

    /// A safe, well-established SF Symbol for this event type.
    var systemImage: String {
        switch self {
        case .aircraftLoaded, .aircraftChanged: return "airplane.circle"
        case .enteredTaxi: return "arrow.triangle.turn.up.right.circle"
        case .takeoffDetected: return "airplane.departure"
        case .enteredClimb: return "arrow.up.forward.circle"
        case .enteredCruise: return "airplane"
        case .enteredDescent: return "arrow.down.forward.circle"
        case .enteredApproach: return "airplane.arrival"
        case .landingDetected: return "airplane.arrival"
        case .flightCompleted: return "checkmark.circle"
        case .telemetryLost: return "antenna.radiowaves.left.and.right.slash"
        case .telemetryRecovered: return "antenna.radiowaves.left.and.right"
        }
    }
}
