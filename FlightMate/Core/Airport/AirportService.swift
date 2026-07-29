//
//  AirportService.swift
//  FlightMate
//
//  Resolves and looks up airport data relevant to the current flight.
//

import Combine
import Foundation

/// Airport lookup capabilities used to enrich the AI's flight context.
protocol AirportProviding {
    /// Looks up an airport by its ICAO identifier (case-insensitive).
    func airport(icao: String) -> Airport?

    /// Returns the single closest airport to `coordinate`, if any are loaded.
    func nearestAirport(to coordinate: GeoCoordinate) -> Airport?

    /// Returns up to `limit` airports closest to `coordinate`, nearest first.
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport]

    /// Search by ICAO, name, or municipality. Empty query returns [].
    /// Results are capped at `limit` (ICAO prefix matches first).
    func searchAirports(query: String, limit: Int) -> [Airport]

    /// Great-circle distance between two airports, in nautical miles.
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double
}

/// Default `AirportProviding` implementation backed by bundled reference
/// data loaded once at initialization time.
final class AirportService: AirportProviding, ObservableObject {
    private let allAirports: [Airport]
    private let airportsByICAO: [String: Airport]

    /// - Parameter loader: Source of bundled reference data. Injected so
    ///   this service can be unit tested with fake/fixture data.
    init(loader: ReferenceDataLoading = ReferenceDataLoader()) {
        let airports = (try? loader.loadAirports()) ?? []
        self.allAirports = airports
        self.airportsByICAO = Dictionary(
            airports.map { ($0.icaoCode.uppercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func airport(icao: String) -> Airport? {
        airportsByICAO[icao.uppercased()]
    }

    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? {
        nearestAirports(to: coordinate, limit: 1).first
    }

    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] {
        guard limit > 0 else { return [] }

        return allAirports
            .map { airport in (airport, GeoDistance.nauticalMiles(from: coordinate, to: airport.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    func searchAirports(query: String, limit: Int = 40) -> [Airport] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        let needle = trimmed.uppercased()
        var icaoPrefix: [Airport] = []
        var icaoContains: [Airport] = []
        var nameMatches: [Airport] = []

        for airport in allAirports {
            let icao = airport.icaoCode.uppercased()
            if icao.hasPrefix(needle) {
                icaoPrefix.append(airport)
            } else if icao.contains(needle) {
                icaoContains.append(airport)
            } else if airport.name.uppercased().contains(needle)
                || (airport.municipality?.uppercased().contains(needle) ?? false) {
                nameMatches.append(airport)
            }
            if icaoPrefix.count >= limit { break }
        }

        var results: [Airport] = []
        results.append(contentsOf: icaoPrefix)
        if results.count < limit {
            results.append(contentsOf: icaoContains.prefix(limit - results.count))
        }
        if results.count < limit {
            results.append(contentsOf: nameMatches.prefix(limit - results.count))
        }
        return Array(results.prefix(limit))
    }

    func distanceBetween(_ first: Airport, _ second: Airport) -> Double {
        GeoDistance.nauticalMiles(from: first.coordinate, to: second.coordinate)
    }
}
