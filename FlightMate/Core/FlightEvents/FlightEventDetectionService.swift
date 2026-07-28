//
//  FlightEventDetectionService.swift
//  FlightMate
//
//  Pure interpretation logic: turns one FlightAnalysis transition (plus a
//  small piece of carried-forward state) into zero or more FlightEventTypes.
//  No networking, no timers, no shared state -- everything needed is
//  passed in as arguments, which is what keeps this trivially unit
//  testable.
//
//  FlightEventEngine (stateful) is the only caller -- see that type for how
//  DetectionState is threaded across observations and turned into
//  published FlightEvents.
//

import Foundation

/// Stateless interpretation of one `FlightAnalysis` transition into zero
/// or more `FlightEventType`s.
///
/// Consumes `FlightAnalysis` only -- never raw telemetry, never
/// `AeroflySession`/`main.mcf`, never anything `FlightAnalysisEngine`
/// hasn't already published. Never duplicates flight-phase-detection
/// logic; it only watches the phase (and other) values `FlightAnalysis`
/// already exposes for *changes*.
enum FlightEventDetectionService {
    /// A pending event before it's stamped with an ID/timestamp by
    /// `FlightEventEngine`.
    typealias PendingEvent = (type: FlightEventType, metadata: FlightEventMetadata?)

    /// The small amount of memory that can't be derived from comparing
    /// just two consecutive `FlightAnalysis` values -- each field is a
    /// one-shot latch, documented at its use site below.
    struct DetectionState: Equatable {
        var hasBeenAirborneThisSession = false
        var isTelemetryCurrentlyLost = false
        var lastKnownAircraft: ResolvedAircraft?
    }

    /// Compares `previous` to `current` and returns every event that
    /// transition produced (zero, one, or several -- e.g. an aircraft
    /// change and a phase change can land in the same `FlightAnalysis`
    /// update), alongside the `DetectionState` to carry into the next
    /// call.
    static func detectEvents(
        previous: FlightAnalysis,
        current: FlightAnalysis,
        state: DetectionState
    ) -> (events: [PendingEvent], updatedState: DetectionState) {
        var newState = state
        var emitted: [PendingEvent] = []

        detectAircraftEvents(current: current, state: &newState, emitted: &emitted)
        detectPhaseEntryEvents(previous: previous, current: current, emitted: &emitted)
        detectFlightCompleted(previous: previous, current: current, state: &newState, emitted: &emitted)
        detectTelemetryEvents(previous: previous, current: current, state: &newState, emitted: &emitted)

        return (emitted, newState)
    }

    // MARK: - Aircraft identity

    /// `nil -> known` emits `.aircraftLoaded`; `known -> different known`
    /// emits `.aircraftChanged` with both aircraft attached as metadata.
    /// A transient `nil` on `current` (session momentarily has no
    /// aircraft selection) never clears `lastKnownAircraft` and never
    /// emits anything -- mirrors `SessionMetricsTracker`'s existing
    /// transient-nil tolerance, for the same reason: a `main.mcf`
    /// re-parse shouldn't be able to manufacture a spurious "reload."
    /// Identity is compared on `aircraftCode` alone, not full
    /// `ResolvedAircraft` equality, so an unrelated livery/resolution-
    /// status change never counts as a new aircraft.
    private static func detectAircraftEvents(
        current: FlightAnalysis, state: inout DetectionState, emitted: inout [PendingEvent]
    ) {
        guard let currentAircraft = current.resolvedAircraft else { return }

        if let lastKnown = state.lastKnownAircraft {
            if lastKnown.aircraftCode != currentAircraft.aircraftCode {
                emitted.append((.aircraftChanged, .aircraftChange(previous: lastKnown, current: currentAircraft)))
            }
        } else {
            emitted.append((.aircraftLoaded, nil))
        }
        state.lastKnownAircraft = currentAircraft
    }

    // MARK: - Phase-entry events

    /// Drives 6 of the 11 event types generically: entering one of these
    /// phases (from any other phase) emits the mapped event exactly
    /// once. Adding a future phase-entry event is a one-line addition
    /// here -- `.parked` is deliberately absent; reaching it is handled
    /// separately by `detectFlightCompleted` below, since not every
    /// arrival at `.parked` represents a completed flight.
    private static let phaseEntryEvents: [FlightPhase: FlightEventType] = [
        .taxi: .enteredTaxi,
        .takeoff: .takeoffDetected,
        .cruise: .enteredCruise,
        .descent: .enteredDescent,
        .approach: .enteredApproach,
        .landing: .landingDetected
    ]

    private static func detectPhaseEntryEvents(
        previous: FlightAnalysis, current: FlightAnalysis, emitted: inout [PendingEvent]
    ) {
        guard previous.flightPhase != current.flightPhase,
              let eventType = phaseEntryEvents[current.flightPhase]
        else { return }
        emitted.append((eventType, nil))
    }

    // MARK: - Flight completed

    /// `hasBeenAirborneThisSession` is a one-shot latch: set the instant
    /// the phase becomes airborne (`FlightPhase.isAirborne`), consumed
    /// (and reset) the instant the aircraft reaches `.parked` again.
    /// Without this latch, taxiing, a touch-and-go, or a short ground
    /// stop would all look identical to a genuinely completed flight --
    /// landing and taxiing back in are *not* the end of the flight, only
    /// reaching `.parked` after actually having flown is.
    private static func detectFlightCompleted(
        previous: FlightAnalysis, current: FlightAnalysis, state: inout DetectionState, emitted: inout [PendingEvent]
    ) {
        if current.flightPhase.isAirborne {
            state.hasBeenAirborneThisSession = true
        }

        guard current.flightPhase == .parked,
              previous.flightPhase != .parked,
              state.hasBeenAirborneThisSession
        else { return }

        emitted.append((.flightCompleted, nil))
        state.hasBeenAirborneThisSession = false
    }

    // MARK: - Telemetry health

    /// `isTelemetryCurrentlyLost` distinguishes a genuine recovery from
    /// the very first `.acquiring -> .live` transition at startup, which
    /// is not a "recovery" -- there was nothing to recover from. Without
    /// this latch, `previous.telemetryHealth != .live` would be true on
    /// both the very first connection and an actual reconnect, and the
    /// two are indistinguishable from a single `previous`/`current` pair
    /// alone.
    private static func detectTelemetryEvents(
        previous: FlightAnalysis, current: FlightAnalysis, state: inout DetectionState, emitted: inout [PendingEvent]
    ) {
        let wasLive = previous.telemetryHealth == .live
        let isLive = current.telemetryHealth == .live

        if wasLive, !isLive {
            emitted.append((.telemetryLost, nil))
            state.isTelemetryCurrentlyLost = true
        } else if !wasLive, isLive, state.isTelemetryCurrentlyLost {
            emitted.append((.telemetryRecovered, nil))
            state.isTelemetryCurrentlyLost = false
        }
    }
}
