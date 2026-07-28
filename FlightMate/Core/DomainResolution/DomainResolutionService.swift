//
//  DomainResolutionService.swift
//  FlightMate
//
//  Default DomainResolving implementation. Resolves raw Aerofly identifiers
//  (as carried by AeroflySession) into bundled reference data, by composing
//  the existing AirportService/AircraftService rather than duplicating
//  their loading/lookup logic.
//
//  This is a dedicated layer, not merged into AirportService/
//  AircraftService: those two only know about their own bundled dataset
//  and raw codes. This service is the one place that understands how an
//  AeroflySession's cross-cutting identifiers (an aircraft+livery pair, an
//  airport+runway pair) compose into a single resolved domain object, with
//  a status and a developer-facing diagnostic report alongside it.
//
//  See DomainResolutionService+Report.swift for the private helpers that
//  build the DomainResolutionReport returned by resolve(_ session:).
//

import Foundation
import Combine

/// Key for memoizing livery lookups, which are scoped to a specific
/// aircraft (the same livery code can exist under multiple aircraft).
struct LiveryCacheKey: Hashable {
    let aircraftCode: String
    let liveryCode: String
}

/// Default `DomainResolving` implementation, backed by the existing
/// `AircraftProviding`/`AirportProviding` services plus an injected
/// `CountryResolving` (currently always `UnavailableCountryResolver`).
final class DomainResolutionService: DomainResolving, ObservableObject {
    private let aircraftProvider: AircraftProviding
    private let airportProvider: AirportProviding
    private let countryResolver: CountryResolving

    /// Memoized lookups. Not needed for performance today --
    /// `AircraftProviding`/`AirportProviding` are already O(1) dictionary
    /// lookups over data loaded once at init -- but this is deliberately
    /// the one place future, potentially more expensive resolvers
    /// (navaids, procedures, remote lookups) get caching for free.
    private var aircraftCache: [String: Aircraft?] = [:]
    private var airportCache: [String: Airport?] = [:]
    private var liveryCache: [LiveryCacheKey: AircraftLivery?] = [:]
    private var countryCache: [String: String?] = [:]

    /// - Parameters:
    ///   - aircraftProvider: Source of bundled aircraft/livery data.
    ///   - airportProvider: Source of bundled airport data.
    ///   - countryResolver: Source of country data. Defaults to
    ///     `UnavailableCountryResolver` since no country dataset is
    ///     bundled yet -- swap this to add real country resolution later
    ///     without touching `ResolvedAirport` or any call site.
    init(
        aircraftProvider: AircraftProviding = AircraftService(),
        airportProvider: AirportProviding = AirportService(),
        countryResolver: CountryResolving = UnavailableCountryResolver()
    ) {
        self.aircraftProvider = aircraftProvider
        self.airportProvider = airportProvider
        self.countryResolver = countryResolver
    }

    // MARK: - Aircraft

    func resolveAircraft(aeroflyCode: String) -> Aircraft? {
        cached(aeroflyCode, in: &aircraftCache) { [aircraftProvider] in
            aircraftProvider.aircraft(id: aeroflyCode)
        }
    }

    func resolveLivery(aeroflyCode: String, forAircraft aircraftAeroflyCode: String) -> AircraftLivery? {
        let key = LiveryCacheKey(aircraftCode: aircraftAeroflyCode, liveryCode: aeroflyCode)
        return cached(key, in: &liveryCache) { [aircraftProvider] in
            aircraftProvider.liveries(for: aircraftAeroflyCode).first { $0.aeroflyCode == aeroflyCode }
        }
    }

    func resolve(_ selection: AeroflySession.AircraftSelection) -> ResolvedAircraft {
        let aircraft = resolveAircraft(aeroflyCode: selection.aeroflyCode)
        let livery = aircraft == nil
            ? nil
            : resolveLivery(aeroflyCode: selection.liveryCode, forAircraft: selection.aeroflyCode)

        return ResolvedAircraft(
            aircraftCode: selection.aeroflyCode,
            liveryCode: selection.liveryCode,
            aircraft: aircraft,
            livery: livery
        )
    }

    // MARK: - Airport

    func resolveAirport(icaoCode: String) -> Airport? {
        cached(icaoCode, in: &airportCache) { [airportProvider] in
            airportProvider.airport(icao: icaoCode)
        }
    }

    func resolveRunway(icaoCode: String, identifier: String) -> Runway? {
        resolveAirport(icaoCode: icaoCode)?.runways.first { $0.identifier == identifier }
    }

    func resolveCountry(forICAO icaoCode: String) -> String? {
        cached(icaoCode, in: &countryCache) { [countryResolver] in
            countryResolver.resolveCountry(forICAO: icaoCode)
        }
    }

    func resolve(_ reference: AeroflySession.RunwayReference) -> ResolvedAirport {
        let airport = resolveAirport(icaoCode: reference.airportCode)
        let runway: Runway? = {
            guard airport != nil, let identifier = reference.runwayIdentifier else { return nil }
            return resolveRunway(icaoCode: reference.airportCode, identifier: identifier)
        }()
        let country = airport == nil ? nil : resolveCountry(forICAO: reference.airportCode)

        return ResolvedAirport(
            icaoCode: reference.airportCode,
            runwayIdentifier: reference.runwayIdentifier,
            airport: airport,
            runway: runway,
            country: country
        )
    }

    // MARK: - Session

    func resolve(_ session: AeroflySession) -> (resolved: ResolvedSession, report: DomainResolutionReport) {
        var entries: [DomainResolutionEntry] = []

        let resolvedAircraft = session.aircraft.map(resolve)
        appendAircraftEntries(for: resolvedAircraft, into: &entries)

        let resolvedDeparture = session.departure.map(resolve)
        appendAirportEntries(
            for: resolvedDeparture,
            fieldPrefix: "departure",
            missingDetail: "no departure recorded in session",
            into: &entries
        )

        let resolvedDestination = session.destination.map(resolve)
        appendAirportEntries(
            for: resolvedDestination,
            fieldPrefix: "destination",
            missingDetail: "no flight plan set",
            into: &entries
        )

        let resolved = ResolvedSession(
            aircraft: resolvedAircraft,
            departure: resolvedDeparture,
            destination: resolvedDestination
        )
        return (resolved, DomainResolutionReport(entries: entries, generatedAt: Date()))
    }

    // MARK: - Memoization

    /// Generic memoization helper. `Value` is expected to itself be an
    /// `Optional` (e.g. `Aircraft?`), so a dictionary lookup miss (`nil`
    /// outer optional) is distinguishable from a cached "known not
    /// found" result (non-`nil` outer optional wrapping a `nil` inner
    /// value) -- misses get cached too, not just hits.
    private func cached<Key: Hashable, Value>(
        _ key: Key,
        in cache: inout [Key: Value],
        compute: () -> Value
    ) -> Value {
        if let cachedValue = cache[key] {
            return cachedValue
        }
        let value = compute()
        cache[key] = value
        return value
    }
}
