//
//  SessionMetrics.swift
//  FlightMate
//
//  Cumulative, session-scoped bookkeeping produced by
//  SessionMetricsTracking -- see that protocol for the reset rules.
//

import Foundation

/// Cumulative metrics for the current flight session, as tracked by
/// `SessionMetricsTracking`.
struct SessionMetrics: Equatable {
    /// Running odometer-style total of position deltas since the current
    /// session began (or since the app started, if identity is unknown).
    var distanceTraveledNauticalMiles: Double = 0

    /// When the current session's tracking began. `nil` only before the
    /// very first `record(_:)` call.
    var flightStartDate: Date?

    /// Elapsed time since `flightStartDate`, recomputed on every
    /// `record(_:)` call. `nil` until `flightStartDate` is set.
    var durationSeconds: TimeInterval?
}
