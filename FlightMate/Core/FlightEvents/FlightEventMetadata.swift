//
//  FlightEventMetadata.swift
//  FlightMate
//
//  Optional, event-specific payload for a FlightEvent, for the rare cases
//  where the event's own FlightAnalysis snapshot doesn't carry enough
//  information by itself.
//

import Foundation

/// Extra, strongly-typed detail attached to specific `FlightEvent`s.
///
/// Deliberately a separate, open enum rather than fields bolted onto
/// `FlightEvent` (or a generic `[String: String]` bag): most events need
/// no metadata at all -- `event.analysis` already carries the full
/// current state -- so only the events that need something `analysis`
/// can't express get a case here. Future event types add new cases to
/// this enum without changing `FlightEvent`'s shape or `FlightEventType`
/// itself.
enum FlightEventMetadata: Equatable {
    /// Attached to `.aircraftChanged`. `analysis.resolvedAircraft` only
    /// ever holds the *new* aircraft, so the previous one is carried here
    /// explicitly for consumers that want to say e.g. "switched from the
    /// A320 to the C172."
    case aircraftChange(previous: ResolvedAircraft, current: ResolvedAircraft)
}
