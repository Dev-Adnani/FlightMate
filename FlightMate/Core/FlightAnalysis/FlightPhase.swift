//
//  FlightPhase.swift
//  FlightMate
//
//  The set of flight phases FlightAnalysisService can currently
//  distinguish between, using only telemetry, session, and resolved
//  reference data -- see FlightAnalysisService+Phase.swift for the
//  detection logic.
//

import Foundation

/// A coarse-grained phase of flight, as interpreted by
/// `FlightAnalysisService`.
///
/// Deliberately limited to these 9 cases for this milestone -- no Go
/// Around, Holding Pattern, Stable Approach, or Flare. Those require
/// additional signal (e.g. a future Flight Event Engine watching phase
/// transitions over time) that doesn't exist yet.
enum FlightPhase: Equatable {
    /// No telemetry has been received yet; phase cannot be determined.
    case unknown
    case parked
    case taxi
    case takeoff
    case climb
    case cruise
    case descent
    case approach
    case landing
}
