//
//  FlightAnalysisEngine.swift
//  FlightMate
//
//  Stateful orchestrator: observes FlightContextEngine's published
//  context, resolves it into domain objects via DomainResolutionService/
//  AirportService, tracks session bookkeeping via SessionMetricsTracking,
//  and delegates the actual interpretation to the pure FlightAnalysisService
//  -- publishing the result as FlightAnalysis.
//
//  No UI, no AI -- this milestone only publishes FlightAnalysis for a
//  future consumer (the planned Flight Event Engine) to observe.
//

import Combine
import Foundation

/// Combines live `FlightContext` with resolved session/reference data into
/// a single, observable `FlightAnalysis`.
///
/// ## Dependency injection
/// Not a singleton. `FlightContextEngine` is a required dependency;
/// `domainResolver`, `airportProvider`, and `sessionMetricsTracker` all
/// have real default implementations but can be swapped for fakes in
/// tests, mirroring every other engine/service in this codebase.
///
/// ## How it works
/// Subscribes to `flightContextEngine.$context`. On every update:
/// 1. Resolves the current `AeroflySession` (if any) into a
///    `ResolvedSession` via `domainResolver`.
/// 2. Looks up the nearest airport to `context.bestKnownPosition` via
///    `airportProvider`, then wraps it into a `ResolvedAirport` --
///    everything above Domain Resolution consumes resolved objects only,
///    even though a geographic nearest-neighbor lookup isn't itself a
///    session-declared reference `DomainResolutionService` can resolve.
/// 3. Records the observation with `sessionMetricsTracker`.
/// 4. Delegates to `FlightAnalysisService.analyze(...)`, which is the
///    single source of aviation knowledge for the resulting
///    `FlightAnalysis` -- this type contains no interpretation logic of
///    its own.
@MainActor
final class FlightAnalysisEngine: ObservableObject {

    /// The latest flight interpretation. Updated every time
    /// `flightContextEngine.context` changes.
    @Published private(set) var analysis: FlightAnalysis = .idle

    private let domainResolver: DomainResolving
    private let airportProvider: AirportProviding
    private let sessionMetricsTracker: SessionMetricsTracking
    private let now: () -> Date

    private var previousContext: FlightContext?
    private var cancellable: AnyCancellable?

    /// - Parameters:
    ///   - flightContextEngine: The combined telemetry + session source to
    ///     observe.
    ///   - domainResolver: Resolves raw session codes into domain objects.
    ///   - airportProvider: Source of the nearest-airport lookup.
    ///   - sessionMetricsTracker: Owns cumulative distance/duration
    ///     bookkeeping -- see `SessionMetricsTracking`.
    ///   - now: Injected clock, for deterministic tests.
    init(
        flightContextEngine: FlightContextEngine,
        domainResolver: DomainResolving = DomainResolutionService(),
        airportProvider: AirportProviding = AirportService(),
        sessionMetricsTracker: SessionMetricsTracking = SessionMetricsTracker(),
        now: @escaping () -> Date = Date.init
    ) {
        self.domainResolver = domainResolver
        self.airportProvider = airportProvider
        self.sessionMetricsTracker = sessionMetricsTracker
        self.now = now

        analyze(flightContextEngine.context)

        cancellable = flightContextEngine.$context
            .sink { [weak self] context in
                self?.analyze(context)
            }
    }

    private func analyze(_ context: FlightContext) {
        let resolvedSession: ResolvedSession? = context.aeroflySession.map { domainResolver.resolve($0).resolved }
        let nearestAirport = resolvedNearestAirport(to: context.bestKnownPosition)

        sessionMetricsTracker.record(context)

        analysis = FlightAnalysisService.analyze(
            currentContext: context,
            previousContext: previousContext,
            previousAnalysis: analysis,
            resolvedSession: resolvedSession,
            nearestAirport: nearestAirport,
            sessionMetrics: sessionMetricsTracker.metrics,
            now: now()
        )

        previousContext = context
    }

    /// Looks up the nearest bundled airport and wraps it as a
    /// `ResolvedAirport` (`runwayIdentifier`/`runway`/`country` all `nil`
    /// -- a geographic nearest-neighbor query has no runway of its own,
    /// unlike a session-declared `RunwayReference`).
    private func resolvedNearestAirport(to position: GeoCoordinate?) -> ResolvedAirport? {
        guard let position, let airport = airportProvider.nearestAirport(to: position) else { return nil }
        return ResolvedAirport(icaoCode: airport.icaoCode, runwayIdentifier: nil, airport: airport, runway: nil, country: nil)
    }
}
