//
//  FlightHistory.swift
//  FlightMate
//
//  The published output of the Flight History Engine: the ordered,
//  in-memory timeline of one flight session, built entirely from
//  FlightEvents. Produced by FlightHistoryService, published by
//  FlightHistoryEngine.
//

import Foundation

/// The complete, ordered record of one flight -- from the moment an
/// aircraft was loaded (preflight events) through takeoff to the moment
/// it either completed normally or was aborted.
///
/// **Option A semantics:** the timeline begins at aircraft load so taxi
/// and preflight events are preserved, but the *flight clock*
/// (`takeoffTime` / `flightDurationSeconds`) starts only on
/// `takeoffDetected`. UI should never call the app process a "session."
///
/// This is deliberately *not* a replay system, persistence, or SwiftData
/// model -- it's an in-memory timeline only. It reuses `FlightEvent`
/// directly for its entries (no separate wrapper type): `FlightEvent`
/// already carries a stable `eventId`, `timestamp`, `type`, `severity`,
/// and the full `FlightAnalysis` snapshot at the moment it fired, so
/// treating `FlightEvent` as the single source of truth avoids duplicating
/// any of that. `currentAircraft`/`departureAirport`/`destinationAirport`/
/// `durationSeconds` below are all read straight off the most recent
/// event's `analysis` snapshot for the same reason -- this type never
/// recomputes or duplicates `FlightAnalysis`/`FlightEventDetectionService`
/// logic, it only ever reads what's already been published.
///
/// `events` only ever grows by appending -- once an event is in the
/// timeline it is never reordered or modified, per the milestone's hard
/// requirement. Mutation happens exclusively through `appending(_:)` and
/// `finalized(as:at:)`, both of which return a new value rather than
/// mutating in place, so existing references (e.g. one already stored in
/// `completedHistories`) can never be changed out from under a caller.
struct FlightHistory: Identifiable, Equatable {
    /// Stable identity for this specific flight session, independent of
    /// any one event's `eventId`.
    let id: UUID

    /// When this history began -- the timestamp of the `aircraftLoaded`/
    /// `aircraftChanged` event that started it (see `FlightHistoryService`).
    let startTime: Date

    /// The ordered timeline of everything that happened during this
    /// flight, oldest first. Never empty -- every history is seeded with
    /// exactly one event at construction.
    private(set) var events: [FlightEvent]

    /// This history's lifecycle state -- see `FlightHistoryStatus`.
    private(set) var status: FlightHistoryStatus

    /// When this history stopped accepting new events -- `nil` while
    /// `status == .active`. Recorded as the timestamp of whichever event
    /// caused the history to end (`flightCompleted` for `.completed`, or
    /// the *next* flight's opening `aircraftChanged` for `.aborted` -- see
    /// `FlightHistoryService`).
    private(set) var endTime: Date?

    /// When `takeoffDetected` first fired on this history -- `nil` until
    /// then. The flight clock and "current flight" identity start here,
    /// not at `startTime` (aircraft load).
    private(set) var takeoffTime: Date?

    /// The aircraft flying this flight, if known -- read from the most
    /// recent event's `FlightAnalysis` snapshot, never tracked separately.
    var currentAircraft: ResolvedAircraft? { events.last?.analysis.resolvedAircraft }

    /// Departure airport, if known -- same rationale as `currentAircraft`.
    var departureAirport: ResolvedAirport? { events.last?.analysis.resolvedDeparture }

    /// Destination airport, if known -- same rationale as `currentAircraft`.
    var destinationAirport: ResolvedAirport? { events.last?.analysis.resolvedDestination }

    /// True once takeoff has been recorded -- the unit of "one flight."
    var hasStartedFlight: Bool { takeoffTime != nil }

    /// Elapsed time from takeoff to the latest event (or `endTime` when
    /// finalized). `nil` until takeoff. Snapshot as-of-last-event -- not a
    /// live ticking clock (histories only advance on `FlightEvent`s).
    var flightDurationSeconds: TimeInterval? {
        guard let takeoffTime else { return nil }
        let end = endTime ?? events.last?.timestamp
        guard let end else { return nil }
        return max(0, end.timeIntervalSince(takeoffTime))
    }

    /// Analysis-derived session metrics duration (aircraft-load based).
    /// Prefer `flightDurationSeconds` for product UI (takeoff → end).
    var durationSeconds: TimeInterval? { events.last?.analysis.estimatedSessionDurationSeconds }

    /// Seeds a brand-new, `.active` history with its very first timeline
    /// entry. Only ever called by `FlightHistoryService`.
    init(id: UUID, firstEvent: FlightEvent) {
        self.id = id
        self.startTime = firstEvent.timestamp
        self.events = [firstEvent]
        self.status = .active
        self.endTime = nil
        self.takeoffTime = firstEvent.type == .takeoffDetected ? firstEvent.timestamp : nil
    }

    /// Returns a copy with `event` appended to the end of the timeline.
    /// Every existing entry is left untouched. Latches `takeoffTime` on the
    /// first `takeoffDetected` only (touch-and-goes keep the original clock).
    func appending(_ event: FlightEvent) -> FlightHistory {
        var copy = self
        copy.events.append(event)
        if event.type == .takeoffDetected, copy.takeoffTime == nil {
            copy.takeoffTime = event.timestamp
        }
        return copy
    }

    /// Returns a copy closed out with the given terminal `status` at `time`.
    /// Callers are expected to pass `.completed` or `.aborted` -- never
    /// `.active`, which is only ever the state a history starts in.
    func finalized(as status: FlightHistoryStatus, at time: Date) -> FlightHistory {
        var copy = self
        copy.status = status
        copy.endTime = time
        return copy
    }
}
