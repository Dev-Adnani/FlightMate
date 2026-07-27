//
//  ReferenceDataLoaderIntegrationTests.swift
//  FlightMateTests
//
//  Exercises ReferenceDataLoader against the real bundled resources
//  (FlightMateTests is hosted inside the FlightMate.app process, so
//  Bundle.main here is the actual app bundle — this catches resource
//  naming / bundling mistakes that fixture-based tests cannot).
//

import Testing
@testable import FlightMate

struct ReferenceDataLoaderIntegrationTests {

    @Test func loadsBundledAirportsGeoJSON() throws {
        let airports = try ReferenceDataLoader().loadAirports()

        #expect(airports.count > 9_800)
        #expect(airports.contains { $0.icaoCode == "KSFO" })

        // Regression check: this airport is only present in airports.geojson,
        // not in the smaller coordinate-only files we previously bundled.
        #expect(airports.contains { $0.icaoCode == "K39P" })
    }

    @Test func bundledAirportsHaveElevationAndCategory() throws {
        let airports = try ReferenceDataLoader().loadAirports()
        let ksfo = try #require(airports.first { $0.icaoCode == "KSFO" })

        #expect(ksfo.elevationFt != nil)
        #expect(ksfo.category == .largeAirport)
    }

    @Test func loadsBundledAircraftJSON() throws {
        let aircraft = try ReferenceDataLoader().loadAircraft()

        #expect(aircraft.count == 44)
        #expect(aircraft.contains { $0.aeroflyCode == "a320_neo" })
    }

    @Test func loadsBundledAircraftLiveries() throws {
        let liveryGroups = try ReferenceDataLoader().loadAircraftLiveries()

        #expect(liveryGroups.count == 44)

        let a320 = try #require(liveryGroups.first { $0.aeroflyCode == "a320_neo" })
        #expect(a320.liveries.contains { $0.icaoCode == "DLH" })
    }

    @Test func aircraftServiceExposesLiveriesFromRealBundle() {
        let service = AircraftService()

        let lufthansaLivery = service.liveries(for: "a320_neo").first { $0.icaoCode == "DLH" }
        #expect(lufthansaLivery?.name == "Lufthansa")

        let matches = service.liveries(icaoCode: "DLH")
        #expect(matches.contains { $0.aircraftId == "a320_neo" })
    }
}
