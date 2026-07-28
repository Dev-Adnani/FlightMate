//
//  FlightAnalysis.swift
//  FlightMate
//
//  The published output of the Flight Analysis Engine: telemetry and
//  session data interpreted into aviation concepts. Produced by
//  FlightAnalysisService, published by FlightAnalysisEngine.
//

import Foundation

/// A deterministic, point-in-time interpretation of the current flight.
///
/// Deliberately excludes raw telemetry passthrough (no lat/lon/altitude/
/// speed fields) -- this layer exists to *interpret* data that already
/// lives on `FlightContext`, not to repeat it. Every domain object exposed
/// here is a resolved object (`ResolvedAirport`, never a bare `Airport`),
/// consistent with the rule that everything above the Domain Resolution
/// layer consumes resolved objects only.
struct FlightAnalysis: Equatable {
    /// The current phase of flight -- see `FlightPhase`.
    var flightPhase: FlightPhase = .unknown

    /// Checkmark-style explanation of why `flightPhase` was chosen, e.g.
    /// `["Altitude at or above cruise threshold", "Vertical speed within
    /// level-flight deadband"]`. Useful for debugging today and
    /// explainable AI later -- see `FlightAnalysisService+Phase.swift`.
    var phaseReasons: [String] = []

    var isClimbing: Bool = false
    var isDescending: Bool = false
    var isTurning: Bool = false

    /// Derived from consecutive altitude samples. `nil` until at least two
    /// samples spaced `FlightAnalysisConstants.minimumSampleIntervalSeconds`
    /// apart have been observed.
    var estimatedVerticalSpeedFeetPerMinute: Double?

    /// Derived from consecutive `bestKnownPosition` samples via
    /// `GeoBearing`. `nil` until two distinct positions have been observed.
    var estimatedGroundTrackDegreesTrue: Double?

    /// Cumulative distance flown this session -- see
    /// `SessionMetricsTracking` for the reset rules.
    var estimatedSessionDistanceNauticalMiles: Double = 0

    /// Elapsed time since session tracking began. Not part of the
    /// milestone's original field list, but published anyway since
    /// `SessionMetricsTracker` computes it regardless -- useful for
    /// future flight-summary UI.
    var estimatedSessionDurationSeconds: TimeInterval?

    /// The nearest known airport to the current position, resolved into
    /// full reference data. `nil` if no position is known yet, or no
    /// bundled airport data is loaded.
    var nearestAirport: ResolvedAirport?

    var distanceToNearestAirportNauticalMiles: Double?

    /// Freshness of the underlying UDP telemetry feed -- see
    /// `TelemetryHealth`.
    var telemetryHealth: TelemetryHealth = .notConnected

    /// How confident this analysis currently is, and why -- see
    /// `AnalysisConfidence`.
    var confidence: AnalysisConfidence = AnalysisConfidence(level: .low, reasons: ["No telemetry received yet"])

    /// When this analysis was produced. `nil` only for `.idle`.
    var analysisTimestamp: Date?

    /// The state before any `FlightContext` has ever been observed.
    static let idle = FlightAnalysis()
}
