//
//  FlightHistoryEngine.swift
//  FlightMate
//
//  Stateful orchestrator: observes FlightEventEngine's published events,
//  threads FlightHistoryService.State across observations, and publishes
//  the result as the current (in-progress) FlightHistory plus a bounded
//  log of previously completed/aborted ones.
//
//  This is NOT a replay system, NOT persistence, and NOT SwiftData --
//  everything lives in memory for the lifetime of the app process. No UI,
//  no AI, no Recorder yet -- this milestone only records and publishes an
//  in-memory timeline for future consumers to build on.
//

import Combine
import Foundation

/// Watches `FlightEventEngine.eventPublisher` and maintains the ordered,
/// in-memory timeline of the current flight (and a bounded log of past
/// ones from this app session).
///
/// ## Dependency injection
/// Not a singleton. `FlightEventEngine` is a required dependency, and it's
/// the *only* thing this engine consumes -- never raw UDP telemetry, never
/// `FlightContext`, never `FlightAnalysis` directly, per this milestone's
/// hard constraint. `FlightEventEngine` itself has no knowledge that
/// `FlightHistoryEngine` exists; it is just another subscriber to its
/// already-public `eventPublisher`.
///
/// ## Why `eventPublisher`, not `events`
/// `FlightEventEngine.eventPublisher` fires every event immediately and
/// unconditionally, regardless of `FlightEventEngine`'s own bounded
/// history -- exactly the "future Flight Recorder" hook that engine's
/// documentation already promises. `FlightHistoryEngine` is precisely that
/// kind of consumer: it needs *every* event, not a possibly-trimmed
/// snapshot array.
///
/// ## Construction-order requirement
/// `eventPublisher` is backed by a `PassthroughSubject`, which -- unlike
/// `FlightEventEngine.$analysis`'s `@Published` source -- never replays
/// anything to a late subscriber. `FlightHistoryEngine` must therefore be
/// constructed immediately after `FlightEventEngine`, before any telemetry/
/// session watching starts (mirroring exactly how `FlightEventEngine`
/// itself is already constructed immediately after `FlightAnalysisEngine`
/// in `FlightMateApp.init()`, before the app's `.task`-driven `.start()`
/// calls run). Under that ordering there is no gap in which an event could
/// be emitted and missed.
@MainActor
final class FlightHistoryEngine: ObservableObject {
    /// The flight currently being recorded, if any. `nil` whenever no
    /// aircraft has been loaded yet, or the most recent history has
    /// already been finalized (`.completed`/`.aborted`) and no new one has
    /// started.
    @Published private(set) var currentHistory: FlightHistory?

    /// Previously finalized histories (`.completed` or `.aborted`) from
    /// this app session, oldest first, bounded to `maxCompletedHistories`.
    /// Purely in-memory -- persisting any of this is a future milestone's
    /// job (see `FlightHistoryService`/this type's own documentation).
    @Published private(set) var completedHistories: [FlightHistory] = []

    private let maxCompletedHistories: Int
    private let makeId: () -> UUID
    private var cancellable: AnyCancellable?

    /// - Parameters:
    ///   - flightEventEngine: The event source to observe. The sole data
    ///     dependency of this engine.
    ///   - maxCompletedHistories: The maximum number of finalized
    ///     histories `completedHistories` retains in memory. Defaults to
    ///     25; tune down in tests to exercise trimming without generating
    ///     dozens of synthetic flights.
    ///   - makeId: Injected `UUID` generator for newly started histories,
    ///     for deterministic tests.
    init(
        flightEventEngine: FlightEventEngine,
        maxCompletedHistories: Int = 25,
        makeId: @escaping () -> UUID = UUID.init
    ) {
        self.maxCompletedHistories = maxCompletedHistories
        self.makeId = makeId

        cancellable = flightEventEngine.eventPublisher
            .sink { [weak self] event in
                self?.handle(event)
            }
    }

    private func handle(_ event: FlightEvent) {
        let updatedState = FlightHistoryService.apply(
            event: event,
            to: FlightHistoryService.State(currentHistory: currentHistory, completedHistories: completedHistories),
            maxCompletedHistories: maxCompletedHistories,
            makeId: makeId
        )
        currentHistory = updatedState.currentHistory
        completedHistories = updatedState.completedHistories
    }
}
