//
//  MapTrailService.swift
//  FlightMate
//
//  Stateful orchestrator: observes FlightContextEngine's live position
//  and FlightHistoryEngine's current flight identity, and maintains an
//  in-memory, sampled geographic trail of the flight currently being
//  recorded.
//

import Combine
import Foundation

/// Records a lightweight, sampled trail of the current flight's ground
/// track, for the Moving Map's breadcrumb overlay.
///
/// ## Why this exists as its own service
/// `FlightAnalysis`/`FlightEvent`/`FlightHistory` deliberately exclude
/// raw position -- see their own documentation -- because that layer
/// answers *what happened*, not *where every sample was*. A breadcrumb
/// trail is a visualization concern, not a domain-analysis one, so it
/// lives here instead of being bolted onto those types.
///
/// ## Dependency injection
/// Not a singleton. `FlightContextEngine` (the sole source of raw
/// position -- see `FlightContext.bestKnownPosition`) and
/// `FlightHistoryEngine` (the sole source of "which flight, if any, is
/// currently being recorded") are both required dependencies.
/// `MapTrailService` never talks to raw UDP telemetry or `main.mcf`
/// directly, and never duplicates `FlightHistoryService`'s transition
/// rules -- it only reacts to `currentHistory`'s identity changing.
///
/// ## Construction-order requirement
/// A single telemetry packet drives both `FlightContextEngine.context`
/// (directly) and `FlightHistoryEngine.currentHistory` (indirectly,
/// through `FlightAnalysisEngine` and `FlightEventEngine`). Combine
/// notifies a `@Published` property's subscribers in subscription order,
/// so on the very packet that starts a new `FlightHistory`,
/// `flightHistoryEngine.currentHistory` is only guaranteed to already
/// reflect that new history by the time *this instance's own* `context`
/// handler runs if `flightHistoryEngine` (and the analysis/event engines
/// upstream of it) were constructed -- and therefore subscribed to
/// `flightContextEngine.$context` -- before this `MapTrailService`. This
/// holds for the app's real construction order (see `FlightMateApp`) and
/// every test's `makeEngines()` helper. Reading `flightHistoryEngine
/// .currentHistory` directly (a plain, always-current property) rather
/// than caching state from `$currentHistory`'s own subscription is what
/// makes that guarantee sufficient -- no additional buffering or replay
/// logic is needed. See `handle(_:FlightContext)` below.
///
/// ## Reusability
/// Deliberately not map-specific internally: it produces a plain
/// `[GeoTrailPoint]` (coordinate + timestamp, no MapKit/CoreLocation
/// dependency anywhere in `Core`), so future consumers -- Replay, GPX
/// export, a standalone Flight Recorder -- can consume the exact same
/// abstraction. Today's Moving Map is simply its first consumer.
///
/// ## Sampling and bounding
/// Both `@Published`s below are safe for a multi-hour flight:
/// `GeoTrailRecordingService.shouldRecord` throttles how densely points
/// are kept (time- and/or distance-based), and `trail` itself is trimmed
/// to `maxSamples` (oldest dropped first), mirroring the bounding
/// pattern already used by `FlightEventEngine.events` and
/// `FlightHistoryEngine.completedHistories`.
@MainActor
final class MapTrailService: ObservableObject {
    /// The current flight's sampled trail, oldest first. Empty until a
    /// flight starts recording and at least one position has been
    /// observed. Persists after `flightCompleted` (nothing to reset to
    /// yet) until the *next* flight actually begins -- see
    /// `GeoTrailRecordingService.shouldReset`.
    @Published private(set) var trail: [GeoTrailPoint] = []

    private let minimumDistanceNauticalMiles: Double
    private let minimumIntervalSeconds: TimeInterval
    private let maxSamples: Int
    private let now: () -> Date

    /// Retained directly (not just subscribed to) so `handle(_:FlightContext)`
    /// can read `currentHistory` synchronously -- see the construction-order
    /// note above.
    private let flightHistoryEngine: FlightHistoryEngine

    /// The id of the `FlightHistory` currently being recorded, if any --
    /// mirrors `flightHistoryEngine.currentHistory?.id` as of the last
    /// observation, kept independently so a transient `nil` (flight
    /// completed, nothing active yet) doesn't erase which flight's trail
    /// is currently on screen.
    private var recordingHistoryId: UUID?
    private var contextCancellable: AnyCancellable?
    private var historyCancellable: AnyCancellable?

    /// - Parameters:
    ///   - flightContextEngine: Source of live position
    ///     (`bestKnownPosition`). The engine's own source precedence
    ///     (UDP over the session's initial position) applies unchanged.
    ///   - flightHistoryEngine: Source of "which flight is currently
    ///     being recorded" -- `currentHistory`.
    ///   - minimumDistanceNauticalMiles: Minimum ground-track movement
    ///     before a new point is recorded, unless
    ///     `minimumIntervalSeconds` has already elapsed. Defaults to
    ///     0.05nm (~92m).
    ///   - minimumIntervalSeconds: Minimum time before a new point is
    ///     recorded, unless `minimumDistanceNauticalMiles` has already
    ///     been covered. Defaults to 3 seconds.
    ///   - maxSamples: Maximum number of points `trail` retains in
    ///     memory before trimming the oldest. Defaults to 3,000 (at the
    ///     default sampling rate, several hours of flight).
    ///   - now: Injected clock, for deterministic tests.
    init(
        flightContextEngine: FlightContextEngine,
        flightHistoryEngine: FlightHistoryEngine,
        minimumDistanceNauticalMiles: Double = 0.05,
        minimumIntervalSeconds: TimeInterval = 3,
        maxSamples: Int = 3_000,
        now: @escaping () -> Date = Date.init
    ) {
        self.minimumDistanceNauticalMiles = minimumDistanceNauticalMiles
        self.minimumIntervalSeconds = minimumIntervalSeconds
        self.maxSamples = maxSamples
        self.now = now
        self.flightHistoryEngine = flightHistoryEngine

        recordingHistoryId = flightHistoryEngine.currentHistory?.id

        historyCancellable = flightHistoryEngine.$currentHistory
            .sink { [weak self] history in
                self?.handle(history)
            }

        contextCancellable = flightContextEngine.$context
            .sink { [weak self] context in
                self?.handle(context)
            }
    }

    private func handle(_ history: FlightHistory?) {
        guard GeoTrailRecordingService.shouldReset(
            observedHistoryId: history?.id,
            recordingHistoryId: recordingHistoryId
        ) else { return }

        recordingHistoryId = history?.id
        trail = []
    }

    private func handle(_ context: FlightContext) {
        // Deliberately reads `flightHistoryEngine.currentHistory` directly
        // rather than the `recordingHistoryId` cache maintained above: on
        // the exact packet that starts a new history, this handler is
        // guaranteed (see the construction-order note on this type) to run
        // *after* that new history already exists, so this is always the
        // freshest possible answer to "is a flight currently being
        // tracked" -- including on that very first packet, whose position
        // must not be lost. A position glimpsed before any aircraft has
        // ever loaded (e.g. the session's parked `initialPosition`) isn't
        // part of any recording, hence `currentHistory == nil` here.
        guard flightHistoryEngine.currentHistory != nil else { return }
        record(context)
    }

    private func record(_ context: FlightContext) {
        guard let position = context.bestKnownPosition else { return }

        let candidate = GeoTrailPoint(coordinate: position, timestamp: now())
        guard GeoTrailRecordingService.shouldRecord(
            candidate: candidate,
            lastRecorded: trail.last,
            minimumDistanceNauticalMiles: minimumDistanceNauticalMiles,
            minimumIntervalSeconds: minimumIntervalSeconds
        ) else { return }

        trail.append(candidate)
        if trail.count > maxSamples {
            trail.removeFirst(trail.count - maxSamples)
        }
    }
}
