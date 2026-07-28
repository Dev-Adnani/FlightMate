//
//  FlightHistoryService.swift
//  FlightMate
//
//  Pure interpretation logic: turns one incoming FlightEvent (plus the
//  engine's carried-forward State) into an updated State. No networking,
//  no timers, no shared state -- everything needed is passed in as
//  arguments, which is what keeps this trivially unit testable.
//
//  FlightHistoryEngine (stateful) is the only caller -- see that type for
//  how State is threaded across observations and published.
//

import Foundation

/// Stateless interpretation of one `FlightEvent` into an updated
/// `FlightHistoryService.State`.
///
/// Consumes `FlightEvent` only -- never raw telemetry, never
/// `FlightContext`, never `FlightAnalysis` directly, and never duplicates
/// any `FlightAnalysisService`/`FlightEventDetectionService` logic. It
/// treats `FlightEvent`s as the single source of truth for everything
/// that happened, and only ever asks "does this event start a history,
/// extend one, or end one?"
enum FlightHistoryService {
    /// The complete in-memory state this service threads across calls:
    /// the flight currently being recorded (if any), and a bounded log of
    /// previously finalized ones from this app session.
    struct State: Equatable {
        var currentHistory: FlightHistory?
        var completedHistories: [FlightHistory] = []
    }

    /// Applies one `event` to `state` and returns the updated state.
    ///
    /// Rules:
    /// 1. **`aircraftLoaded` / `aircraftChanged`** -- these are the only
    ///    event types allowed to *start* a history (every other event
    ///    type arriving with no active history, and no aircraft ever
    ///    loaded yet, is dropped -- there's nothing meaningful to record).
    ///    If a history is already `.active` when one of these arrives,
    ///    that almost certainly means the user loaded a different
    ///    aircraft, restarted the flight, or teleported *before*
    ///    completing the previous one -- so the old history is finalized
    ///    as `.aborted` (moved into `completedHistories`) and a brand-new
    ///    history is started in the same step, seeded with this same
    ///    event as its first entry. There is no idle gap in between: the
    ///    very event that ends the old flight is also the first event of
    ///    the next one. (`aircraftLoaded` only ever fires once per app
    ///    session in practice -- see `FlightEventDetectionService` -- so
    ///    this rule is written symmetrically for both cases rather than
    ///    assuming which one can reach here with a history already active.)
    /// 2. **`flightCompleted`** -- appended to the active history's
    ///    timeline, then that history is finalized as `.completed` and
    ///    moved into `completedHistories`. If no history is active (should
    ///    not normally happen, since `flightCompleted` only ever fires
    ///    after the aircraft has been airborne, which implies an aircraft
    ///    was loaded first), the event is dropped.
    /// 3. **Everything else** (`enteredTaxi`, `takeoffDetected`,
    ///    `enteredCruise`, `enteredDescent`, `enteredApproach`,
    ///    `landingDetected`, `telemetryLost`, `telemetryRecovered`) --
    ///    appended to the active history's timeline if one exists;
    ///    dropped otherwise (per rule 1, only an aircraft event can start
    ///    a history in the first place).
    ///
    /// - Parameters:
    ///   - event: The next `FlightEvent` to fold into `state`.
    ///   - state: The engine's current state.
    ///   - maxCompletedHistories: The maximum number of finalized
    ///     histories (`.completed` or `.aborted`) `completedHistories`
    ///     retains, oldest dropped first.
    ///   - makeId: Injected `UUID` generator for a newly started history,
    ///     for deterministic tests.
    static func apply(
        event: FlightEvent,
        to state: State,
        maxCompletedHistories: Int,
        makeId: () -> UUID = UUID.init
    ) -> State {
        switch event.type {
        case .aircraftLoaded, .aircraftChanged:
            return beginningNewHistory(
                seededWith: event, replacing: state, maxCompletedHistories: maxCompletedHistories, makeId: makeId
            )
        case .flightCompleted:
            return completingCurrentHistory(with: event, in: state, maxCompletedHistories: maxCompletedHistories)
        case .enteredTaxi, .takeoffDetected, .enteredCruise, .enteredDescent, .enteredApproach,
             .landingDetected, .telemetryLost, .telemetryRecovered:
            return appendingToCurrentHistory(event, in: state)
        }
    }

    // MARK: - Starting a history

    private static func beginningNewHistory(
        seededWith event: FlightEvent, replacing state: State, maxCompletedHistories: Int, makeId: () -> UUID
    ) -> State {
        var newState = state

        if let active = newState.currentHistory {
            let aborted = active.finalized(as: .aborted, at: event.timestamp)
            newState.completedHistories = appendBounded(aborted, to: newState.completedHistories, max: maxCompletedHistories)
        }

        newState.currentHistory = FlightHistory(id: makeId(), firstEvent: event)
        return newState
    }

    // MARK: - Completing a history

    private static func completingCurrentHistory(
        with event: FlightEvent, in state: State, maxCompletedHistories: Int
    ) -> State {
        var newState = state
        guard let active = newState.currentHistory else { return newState }

        let completed = active.appending(event).finalized(as: .completed, at: event.timestamp)
        newState.completedHistories = appendBounded(completed, to: newState.completedHistories, max: maxCompletedHistories)
        newState.currentHistory = nil
        return newState
    }

    // MARK: - Extending a history

    private static func appendingToCurrentHistory(_ event: FlightEvent, in state: State) -> State {
        var newState = state
        guard let active = newState.currentHistory else { return newState }
        newState.currentHistory = active.appending(event)
        return newState
    }

    // MARK: - Bounded history list

    private static func appendBounded(_ history: FlightHistory, to list: [FlightHistory], max: Int) -> [FlightHistory] {
        var newList = list
        newList.append(history)
        if newList.count > max {
            newList.removeFirst(newList.count - max)
        }
        return newList
    }
}
