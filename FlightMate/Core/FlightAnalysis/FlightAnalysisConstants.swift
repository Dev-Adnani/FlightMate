//
//  FlightAnalysisConstants.swift
//  FlightMate
//
//  Generic, non-aircraft-specific detection/tuning constants used by
//  FlightAnalysisService. Aircraft performance numbers (cruise speed,
//  approach speed, cruise altitude) intentionally do NOT live here -- see
//  FlightPerformanceProfile.swift -- since those are aircraft
//  characteristics, not generic heuristics, and are expected to grow
//  (flap speeds, rotation speed, touchdown speed, stall margins).
//
//  Single source of truth for every disclosed heuristic constant, so
//  tests reference the same values rather than duplicating magic numbers.
//

import Foundation

/// Generic thresholds/tuning constants for flight-phase and motion
/// detection, independent of which aircraft is currently flown.
enum FlightAnalysisConstants {
    static let parkedSpeedKt = 2.0
    static let taxiUpperBoundKt = 40.0        // typical real-world max taxi speed
    static let verticalSpeedDeadbandFpm = 150.0
    static let turnRateThresholdDegreesPerSecond = 3.0 // standard-rate turn (real aviation constant)
    static let approachProximityNm = 15.0
    static let cruiseAltitudeFraction = 0.8   // fraction of FlightPerformanceProfile.cruiseAltitudeFt considered "at cruise"

    /// How far above `FlightPerformanceProfile.approachAirspeedKts` ground
    /// speed may still be while decelerating and still count as
    /// ".approach" rather than ".descent" -- avoids requiring speed to be
    /// already at approach speed the instant proximity is reached.
    static let approachDecelerationToleranceFactor = 1.5

    static let minimumSampleIntervalSeconds = 0.5 // debounces vertical-speed/ground-track/turn-rate noise
    static let distanceNoiseFloorNm = 0.005   // ~30 ft; ignores GPS jitter while stationary
    static let telemetryFreshnessWindowSeconds = 3.0
}
