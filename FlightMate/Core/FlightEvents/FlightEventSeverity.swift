//
//  FlightEventSeverity.swift
//  FlightMate
//
//  How urgently a FlightEvent should be surfaced to a consumer (UI,
//  notifications, AI tone) -- see FlightEventType.defaultSeverity for how
//  each event type maps to a level.
//

import Foundation

/// A coarse urgency level for a `FlightEvent`.
///
/// Not meaningfully used yet -- every event this milestone emits is
/// `.info` (see `FlightEventType.defaultSeverity`). Introduced now, ahead
/// of need, so future milestones that add real `.warning`/`.critical`
/// events (Overspeed, Late Descent, Stall, Engine Failure, Terrain
/// Warning) can do so without redesigning `FlightEvent`'s shape or any
/// existing consumer that already switches on this type.
enum FlightEventSeverity: Equatable {
    case info
    case warning
    case critical
}
