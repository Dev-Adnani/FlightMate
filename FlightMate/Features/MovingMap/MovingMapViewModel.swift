//
//  MovingMapViewModel.swift
//  FlightMate
//
//  Drives MovingMapView: bridges FlightContextEngine/FlightAnalysisEngine/
//  MapTrailService's domain data into plain, MapKit-ready display state.
//  No navigation math, no domain interpretation of its own -- everything
//  here is already-resolved data, just reshaped for rendering.
//

import Combine
import CoreLocation
import Foundation

/// View model for the Moving Map feature.
///
/// ## Dependency injection
/// Not a singleton. Consumes three existing, already-injected engines --
/// never touches raw UDP telemetry, `main.mcf`, or MapKit's own location
/// services. `FlightContextEngine` is the sole source of live position/
/// heading (`FlightAnalysis` deliberately excludes those -- see its own
/// documentation); `FlightAnalysisEngine` supplies the resolved
/// departure/destination/nearest airports; `MapTrailService` supplies the
/// breadcrumb trail.
///
/// ## Performance
/// `FlightContext` can update at UDP telemetry rates. Publishing a new
/// `aircraftCoordinate` on every single observation would make
/// `MovingMapView` re-render (and MapKit re-lay-out its aircraft
/// annotation) far more often than a human can perceive. `handle(_:)`
/// throttles aircraft position/heading updates to at most once per
/// `minimumPositionUpdateInterval`, independent of how fast telemetry
/// itself arrives -- airport annotations and the route line change far
/// less often and are never throttled.
@MainActor
final class MovingMapViewModel: ObservableObject {
    /// The aircraft's current position, if known. `nil` before any
    /// position (UDP or the session's initial one) has been observed.
    @Published private(set) var aircraftCoordinate: GeoCoordinate?

    /// True heading, in degrees, if known -- see
    /// `FlightContext.headingDegreesTrue`.
    @Published private(set) var aircraftHeadingDegrees: Double?

    /// Departure/destination/nearest airports currently worth pinning,
    /// deduplicated by ICAO so an airport matching more than one role is
    /// only ever shown once.
    @Published private(set) var airportAnnotations: [MovingMapAirportAnnotation] = []

    /// The straight line between departure and destination, if both are
    /// resolved to bundled airport data. `nil` otherwise -- this is
    /// deliberately not a flight-planned route (no waypoints exist
    /// anywhere in this app's domain model), just the two endpoints.
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D]?

    /// The current flight's breadcrumb trail, ready for `MapPolyline`.
    @Published private(set) var trailCoordinates: [CLLocationCoordinate2D] = []

    /// The airport the user has tapped, if any. Selecting the same
    /// airport again clears the selection -- see `selectAirport(_:)`.
    @Published private(set) var selectedAirport: Airport?

    private let minimumPositionUpdateInterval: TimeInterval
    private let now: () -> Date
    private var lastPositionUpdateTimestamp: Date?
    private var cancellables: Set<AnyCancellable> = []

    /// - Parameters:
    ///   - flightContextEngine: Source of live position/heading.
    ///   - flightAnalysisEngine: Source of resolved departure/
    ///     destination/nearest airports.
    ///   - mapTrailService: Source of the current flight's breadcrumb
    ///     trail.
    ///   - minimumPositionUpdateInterval: Minimum time between published
    ///     aircraft position/heading updates, regardless of how often
    ///     `flightContextEngine` itself updates. Defaults to 0.2s (5Hz)
    ///     -- smooth to the eye, far below UDP telemetry rates.
    ///   - now: Injected clock, for deterministic tests.
    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        mapTrailService: MapTrailService,
        minimumPositionUpdateInterval: TimeInterval = 0.2,
        now: @escaping () -> Date = Date.init
    ) {
        self.minimumPositionUpdateInterval = minimumPositionUpdateInterval
        self.now = now

        flightContextEngine.$context
            .sink { [weak self] context in
                self?.handle(context)
            }
            .store(in: &cancellables)

        flightAnalysisEngine.$analysis
            .sink { [weak self] analysis in
                self?.handle(analysis)
            }
            .store(in: &cancellables)

        mapTrailService.$trail
            .sink { [weak self] trail in
                self?.trailCoordinates = trail.map { $0.coordinate.clLocationCoordinate }
            }
            .store(in: &cancellables)
    }

    /// Selects `airport` for its info card, or clears the selection if
    /// `airport` is already selected.
    func selectAirport(_ airport: Airport) {
        selectedAirport = (selectedAirport == airport) ? nil : airport
    }

    func clearSelection() {
        selectedAirport = nil
    }

    private func handle(_ context: FlightContext) {
        guard let position = context.bestKnownPosition else { return }

        let timestamp = now()
        if let lastPositionUpdateTimestamp,
           timestamp.timeIntervalSince(lastPositionUpdateTimestamp) < minimumPositionUpdateInterval {
            return
        }

        lastPositionUpdateTimestamp = timestamp
        aircraftCoordinate = position
        aircraftHeadingDegrees = context.headingDegreesTrue
    }

    private func handle(_ analysis: FlightAnalysis) {
        airportAnnotations = Self.dedupedAnnotations(
            departure: analysis.resolvedDeparture,
            destination: analysis.resolvedDestination,
            nearest: analysis.nearestAirport
        )

        if let departure = analysis.resolvedDeparture?.airport,
           let destination = analysis.resolvedDestination?.airport {
            routeCoordinates = [departure.coordinate.clLocationCoordinate, destination.coordinate.clLocationCoordinate]
        } else {
            routeCoordinates = nil
        }
    }

    /// Builds the deduplicated annotation list, in role-priority order
    /// (departure, then destination, then nearest) -- an airport that
    /// matches an earlier role is never repeated for a later one.
    private static func dedupedAnnotations(
        departure: ResolvedAirport?,
        destination: ResolvedAirport?,
        nearest: ResolvedAirport?
    ) -> [MovingMapAirportAnnotation] {
        var seenICAOCodes: Set<String> = []
        var annotations: [MovingMapAirportAnnotation] = []

        func add(_ resolved: ResolvedAirport?, role: MovingMapAirportAnnotation.Role) {
            guard let airport = resolved?.airport, !seenICAOCodes.contains(airport.icaoCode) else { return }
            seenICAOCodes.insert(airport.icaoCode)
            annotations.append(MovingMapAirportAnnotation(id: airport.icaoCode, role: role, airport: airport))
        }

        add(departure, role: .departure)
        add(destination, role: .destination)
        add(nearest, role: .nearest)

        return annotations
    }
}
