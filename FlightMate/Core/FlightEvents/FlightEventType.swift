//
//  FlightEventType.swift
//  FlightMate
//
//  The initial, closed set of discrete events the Flight Event Engine can
//  detect from FlightAnalysis transitions -- see FlightEventDetectionService
//  for the detection rules.
//

import Foundation

/// One kind of meaningful, discrete transition in the current flight.
///
/// Deliberately limited to these 12 cases for this milestone -- no Go
/// Around, Holding Pattern, Rejected Takeoff, Touchdown Quality, Stable
/// Approach, or emergency events (Overspeed, Stall, Terrain Warning).
/// Those require additional signal and belong to future milestones.
///
/// Naming convention: phases the aircraft *dwells in* for a while use
/// `entered*` (`enteredTaxi`, `enteredClimb`, `enteredCruise`,
/// `enteredDescent`, `enteredApproach`) so a future `exited*` counterpart
/// reads naturally.
/// Genuinely singular, momentary occurrences keep a plain past-tense name
/// (`takeoffDetected`, `landingDetected`, `flightCompleted`,
/// `aircraftLoaded`, `aircraftChanged`, `telemetryLost`,
/// `telemetryRecovered`).
enum FlightEventType: Equatable, Hashable {
    case aircraftLoaded
    case aircraftChanged
    case enteredTaxi
    case takeoffDetected
    case enteredClimb
    case enteredCruise
    case enteredDescent
    case enteredApproach
    case landingDetected
    case flightCompleted
    case telemetryLost
    case telemetryRecovered

    /// The severity to attach to a `FlightEvent` of this type -- see
    /// `FlightEventSeverity`. Every case is `.info` today, even ones that
    /// might intuitively read as `.warning` (e.g. `telemetryLost`):
    /// reclassifying an existing event is a one-line change here whenever
    /// a future milestone actually introduces a severity-driven consumer
    /// (notifications, AI tone), not a redesign of this type or
    /// `FlightEvent` itself.
    var defaultSeverity: FlightEventSeverity {
        switch self {
        case .aircraftLoaded, .aircraftChanged, .enteredTaxi, .takeoffDetected, .enteredClimb,
             .enteredCruise, .enteredDescent, .enteredApproach, .landingDetected, .flightCompleted,
             .telemetryLost, .telemetryRecovered:
            return .info
        }
    }
}
