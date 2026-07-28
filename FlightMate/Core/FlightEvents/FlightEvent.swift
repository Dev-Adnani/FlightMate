//
//  FlightEvent.swift
//  FlightMate
//
//  The published output of the Flight Event Engine: one discrete,
//  meaningful occurrence detected from a FlightAnalysis transition.
//  Produced by FlightEventDetectionService, published by FlightEventEngine.
//

import Foundation

/// One meaningful, discrete occurrence in the current flight -- e.g. "the
/// aircraft just entered cruise" or "the aircraft just landed."
///
/// Deliberately excludes raw telemetry: everything a consumer needs is
/// either `analysis` (the full interpreted state at the moment of the
/// event) or `metadata` (event-specific detail `analysis` can't express).
struct FlightEvent: Equatable {
    /// Stable identity for this specific occurrence -- lets future
    /// consumers (Timeline, Flight Recorder, AI references, debugging,
    /// event replay) refer back to exactly this event rather than a
    /// (type, timestamp) pair.
    let eventId: UUID

    /// What kind of event this is -- see `FlightEventType`.
    let type: FlightEventType

    /// When this event was detected.
    let timestamp: Date

    /// The full `FlightAnalysis` snapshot at the moment this event fired.
    let analysis: FlightAnalysis

    /// How urgently this event should be surfaced -- see
    /// `FlightEventSeverity`. Currently always `type.defaultSeverity`.
    let severity: FlightEventSeverity

    /// Event-specific detail `analysis` alone can't express -- `nil` for
    /// most event types. See `FlightEventMetadata`.
    let metadata: FlightEventMetadata?
}
