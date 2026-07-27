//
//  AircraftServiceTests.swift
//  FlightMateTests
//
//  Exercises AircraftService against an injected FakeReferenceDataLoader,
//  independent of the real app bundle.
//

import Testing
@testable import FlightMate

struct AircraftServiceTests {

    private func makeService() -> AircraftService {
        AircraftService(loader: FakeReferenceDataLoader(
            aircraft: ReferenceDataFixtures.aircraft,
            aircraftLiveries: ReferenceDataFixtures.aircraftLiveries
        ))
    }

    @Test func aircraftLookupByIDSucceeds() {
        let service = makeService()

        #expect(service.aircraft(id: "a320_neo") == ReferenceDataFixtures.a320)
        #expect(service.aircraft(id: "c172") == ReferenceDataFixtures.c172)
    }

    @Test func aircraftLookupReturnsNilForUnknownID() {
        let service = makeService()

        #expect(service.aircraft(id: "does_not_exist") == nil)
    }

    @Test func allAircraftReturnsEveryLoadedAircraft() {
        let service = makeService()

        #expect(Set(service.allAircraft().map(\.aeroflyCode)) == Set(["a320_neo", "c172"]))
    }

    @Test func failedLoadResultsInEmptyServiceRatherThanCrashing() {
        struct LoadFailure: Error {}
        let service = AircraftService(loader: FakeReferenceDataLoader(aircraftError: LoadFailure()))

        #expect(service.aircraft(id: "a320_neo") == nil)
        #expect(service.allAircraft().isEmpty)
    }

    @Test func liveriesForAircraftReturnsBundledLiveries() {
        let service = makeService()

        #expect(service.liveries(for: "a320_neo") == [
            ReferenceDataFixtures.houseLivery,
            ReferenceDataFixtures.lufthansaLivery
        ])
    }

    @Test func liveriesForAircraftWithNoLiveriesIsEmpty() {
        let service = makeService()

        #expect(service.liveries(for: "c172").isEmpty)
    }

    @Test func liveriesForUnknownAircraftIsEmpty() {
        let service = makeService()

        #expect(service.liveries(for: "does_not_exist").isEmpty)
    }

    @Test func liveriesByICAOCodeFindsMatchAcrossAircraft() {
        let service = makeService()

        let matches = service.liveries(icaoCode: "dlh")

        #expect(matches == [AircraftLiveryMatch(aircraftId: "a320_neo", livery: ReferenceDataFixtures.lufthansaLivery)])
    }

    @Test func liveriesByICAOCodeReturnsEmptyForUnknownCode() {
        let service = makeService()

        #expect(service.liveries(icaoCode: "ZZZ").isEmpty)
    }

    @Test func failedLiveriesLoadResultsInEmptyLookupRatherThanCrashing() {
        struct LoadFailure: Error {}
        let service = AircraftService(loader: FakeReferenceDataLoader(
            aircraft: ReferenceDataFixtures.aircraft,
            aircraftLiveriesError: LoadFailure()
        ))

        #expect(service.liveries(for: "a320_neo").isEmpty)
        #expect(service.liveries(icaoCode: "DLH").isEmpty)
    }
}
