//
//  FlightPerformanceProfile.swift
//  FlightMate
//
//  The aircraft performance characteristics relevant to flight-phase
//  detection -- sourced from a resolved aircraft when possible, otherwise
//  a documented generic fallback. Kept distinct from
//  FlightAnalysisConstants: these are aircraft-specific numbers, not
//  generic detection heuristics.
//

import Foundation

/// Aircraft performance numbers consumed by `FlightAnalysisService`'s
/// phase-detection state machine.
///
/// Deliberately extensible: future fields (flap speeds, rotation speed,
/// touchdown speed, stall margins) can be added here without changing any
/// call site, since every profile is always constructed via `make(from:)`.
struct FlightPerformanceProfile: Equatable {
    /// Where this profile's numbers came from.
    enum Source: Equatable {
        /// Real bundled reference data for the currently resolved aircraft.
        case resolvedAircraft
        /// The aircraft could not be resolved; generic numbers are used.
        case genericFallback
    }

    let cruiseSpeedKts: Double
    let approachAirspeedKts: Double

    /// `nil` in the generic fallback -- cruise-altitude-based phase checks
    /// fall back to an altitude-agnostic rule when this is `nil`, rather
    /// than inventing a number for an unknown aircraft.
    let cruiseAltitudeFt: Double?

    let source: Source

    /// Generic numbers used only when the active aircraft cannot be
    /// resolved -- never a substitute for real per-aircraft data when it
    /// is available.
    static let genericFallback = FlightPerformanceProfile(
        cruiseSpeedKts: 250,
        approachAirspeedKts: 90,
        cruiseAltitudeFt: nil,
        source: .genericFallback
    )

    /// Builds a profile from a resolved aircraft selection, falling back
    /// to `genericFallback` when the aircraft itself didn't resolve (or
    /// there was no selection at all).
    static func make(from resolvedAircraft: ResolvedAircraft?) -> FlightPerformanceProfile {
        guard let aircraft = resolvedAircraft?.aircraft else { return .genericFallback }
        return FlightPerformanceProfile(
            cruiseSpeedKts: aircraft.cruiseSpeedKts,
            approachAirspeedKts: aircraft.approachAirspeedKts,
            cruiseAltitudeFt: aircraft.cruiseAltitudeFt,
            source: .resolvedAircraft
        )
    }
}
