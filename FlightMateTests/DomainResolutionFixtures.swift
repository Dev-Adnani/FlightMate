//
//  DomainResolutionFixtures.swift
//  FlightMateTests
//
//  Call-counting test doubles for DomainResolutionService's caching tests.
//  Wrap a real provider and delegate every call, while counting the one
//  method each cache is meant to memoize.
//

import Foundation
@testable import FlightMate

final class CountingAircraftProvider: AircraftProviding {
    private let base: AircraftProviding
    private(set) var aircraftLookupCount = 0

    init(base: AircraftProviding) {
        self.base = base
    }

    func aircraft(id: String) -> Aircraft? {
        aircraftLookupCount += 1
        return base.aircraft(id: id)
    }

    func allAircraft() -> [Aircraft] { base.allAircraft() }
    func liveries(for aircraftId: String) -> [AircraftLivery] { base.liveries(for: aircraftId) }
    func liveries(icaoCode: String) -> [AircraftLiveryMatch] { base.liveries(icaoCode: icaoCode) }
}

final class CountingAirportProvider: AirportProviding {
    private let base: AirportProviding
    private(set) var airportLookupCount = 0

    init(base: AirportProviding) {
        self.base = base
    }

    func airport(icao: String) -> Airport? {
        airportLookupCount += 1
        return base.airport(icao: icao)
    }

    func nearestAirport(to coordinate: GeoCoordinate) -> Airport? { base.nearestAirport(to: coordinate) }
    func nearestAirports(to coordinate: GeoCoordinate, limit: Int) -> [Airport] { base.nearestAirports(to: coordinate, limit: limit) }
    func searchAirports(query: String, limit: Int) -> [Airport] { base.searchAirports(query: query, limit: limit) }
    func distanceBetween(_ first: Airport, _ second: Airport) -> Double { base.distanceBetween(first, second) }
}
