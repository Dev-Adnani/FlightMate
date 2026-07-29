//
//  AirportServiceTests.swift
//  FlightMateTests
//
//  Exercises AirportService against an injected FakeReferenceDataLoader,
//  independent of the real app bundle.
//

import Testing
@testable import FlightMate

struct AirportServiceTests {

    private func makeService() -> AirportService {
        AirportService(loader: FakeReferenceDataLoader(airports: ReferenceDataFixtures.airports))
    }

    @Test func airportLookupIsCaseInsensitive() {
        let service = makeService()

        #expect(service.airport(icao: "aaaa") == ReferenceDataFixtures.origin)
        #expect(service.airport(icao: "AAAA") == ReferenceDataFixtures.origin)
    }

    @Test func airportLookupReturnsNilForUnknownCode() {
        let service = makeService()

        #expect(service.airport(icao: "ZZZZ") == nil)
    }

    @Test func nearestAirportReturnsClosestMatch() {
        let service = makeService()

        let nearest = service.nearestAirport(to: GeoCoordinate(latitude: 0, longitude: 0))

        #expect(nearest == ReferenceDataFixtures.origin)
    }

    @Test func nearestAirportsReturnsResultsOrderedByDistance() {
        let service = makeService()

        let nearest = service.nearestAirports(to: GeoCoordinate(latitude: 0, longitude: 0), limit: 2)

        #expect(nearest.map(\.icaoCode) == ["AAAA", "BBBB"])
    }

    @Test func nearestAirportsRespectsLimit() {
        let service = makeService()

        #expect(service.nearestAirports(to: GeoCoordinate(latitude: 0, longitude: 0), limit: 1).count == 1)
        #expect(service.nearestAirports(to: GeoCoordinate(latitude: 0, longitude: 0), limit: 0).isEmpty)
    }

    @Test func searchAirportsPrefersICAOPrefix() {
        let service = makeService()

        let results = service.searchAirports(query: "AA", limit: 10)

        #expect(results.first?.icaoCode == "AAAA")
    }

    @Test func searchAirportsMatchesName() {
        let service = makeService()

        let results = service.searchAirports(query: ReferenceDataFixtures.origin.name, limit: 10)

        #expect(results.contains(ReferenceDataFixtures.origin))
    }

    @Test func searchAirportsEmptyQueryReturnsNothing() {
        let service = makeService()

        #expect(service.searchAirports(query: "   ", limit: 10).isEmpty)
    }

    @Test func distanceBetweenMatchesGeoDistance() {
        let service = makeService()

        let expected = GeoDistance.nauticalMiles(
            from: ReferenceDataFixtures.origin.coordinate,
            to: ReferenceDataFixtures.oneDegreeEast.coordinate
        )

        let actual = service.distanceBetween(ReferenceDataFixtures.origin, ReferenceDataFixtures.oneDegreeEast)

        #expect(actual == expected)
    }

    @Test func failedLoadResultsInEmptyServiceRatherThanCrashing() {
        struct LoadFailure: Error {}
        let service = AirportService(loader: FakeReferenceDataLoader(airportsError: LoadFailure()))

        #expect(service.airport(icao: "AAAA") == nil)
        #expect(service.nearestAirports(to: GeoCoordinate(latitude: 0, longitude: 0), limit: 5).isEmpty)
    }
}
