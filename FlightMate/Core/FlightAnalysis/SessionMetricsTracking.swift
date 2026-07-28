//
//  SessionMetricsTracking.swift
//  FlightMate
//
//  Protocol for the small collaborator that owns cumulative session
//  bookkeeping (distance, flight start time, duration), kept separate from
//  FlightAnalysisEngine so the engine stays focused on interpreting the
//  current instant, not accumulating long-term state.
//

import Foundation

/// Tracks cumulative, session-scoped flight metrics over time.
///
/// A "session" is identified loosely by the active aircraft/departure
/// airport -- see `SessionMetricsTracker` for the exact reset rules. This
/// is deliberately a narrow, single-purpose collaborator: it knows nothing
/// about flight phases, telemetry health, or resolved domain objects.
protocol SessionMetricsTracking: AnyObject {
    /// The latest cumulative metrics, updated by `record(_:)`.
    var metrics: SessionMetrics { get }

    /// Records one `FlightContext` observation, updating cumulative
    /// distance/duration and resetting them if a new flight session is
    /// detected (aircraft or departure identity changed).
    func record(_ context: FlightContext)
}
