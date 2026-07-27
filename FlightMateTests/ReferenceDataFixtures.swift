//
//  ReferenceDataFixtures.swift
//  FlightMateTests
//
//  Shared test doubles for the reference data layer, so AirportService and
//  AircraftService can be tested without touching the real app bundle.
//

import Foundation
@testable import FlightMate

/// In-memory `ReferenceDataLoading` fixture for tests.
struct FakeReferenceDataLoader: ReferenceDataLoading {
    var airports: [Airport] = []
    var aircraft: [Aircraft] = []
    var aircraftLiveries: [AircraftLiveryGroup] = []
    var airportsError: Error?
    var aircraftError: Error?
    var aircraftLiveriesError: Error?

    func loadAirports() throws -> [Airport] {
        if let airportsError { throw airportsError }
        return airports
    }

    func loadAircraft() throws -> [Aircraft] {
        if let aircraftError { throw aircraftError }
        return aircraft
    }

    func loadAircraftLiveries() throws -> [AircraftLiveryGroup] {
        if let aircraftLiveriesError { throw aircraftLiveriesError }
        return aircraftLiveries
    }
}

enum ReferenceDataFixtures {
    /// Three airports at deterministic coordinates for distance/nearest tests.
    static let origin = Airport(icaoCode: "AAAA", name: "Origin Field", latitude: 0, longitude: 0)
    static let oneDegreeEast = Airport(icaoCode: "BBBB", name: "One Degree East", latitude: 0, longitude: 1)
    static let farAway = Airport(icaoCode: "CCCC", name: "Far Away Field", latitude: 10, longitude: 10)

    static var airports: [Airport] { [origin, oneDegreeEast, farAway] }

    static let a320 = Aircraft(
        aeroflyCode: "a320_neo",
        name: "A320neo",
        nameFull: "Airbus A320neo",
        icaoCode: "A20N",
        tags: ["airplane", "airliner", "jet"],
        approachAirspeedKts: 136,
        cruiseAltitudeFt: 32_000,
        cruiseSpeedKts: 453,
        maximumRangeNm: 3_400,
        maximumLoadRangeNm: 2_450,
        maximumFuelRangeNm: 3_400,
        maximumFerryRangeNm: 4_300,
        maximumFuelMassKg: 19_050.9,
        maximumPayloadKg: 21_000,
        maximumTakeoffMassKg: 79_000,
        operatingEmptyMassKg: 44_300,
        maximumPersonsOnBoard: 201
    )

    static let c172 = Aircraft(
        aeroflyCode: "c172",
        name: "C172",
        nameFull: "Cessna 172",
        icaoCode: "C172",
        tags: ["airplane", "ga"],
        approachAirspeedKts: 65,
        cruiseAltitudeFt: 8_000,
        cruiseSpeedKts: 120,
        maximumRangeNm: 640,
        maximumLoadRangeNm: 640,
        maximumFuelRangeNm: 640,
        maximumFerryRangeNm: 640,
        maximumFuelMassKg: nil,
        maximumPayloadKg: nil,
        maximumTakeoffMassKg: nil,
        operatingEmptyMassKg: nil,
        maximumPersonsOnBoard: 4
    )

    static var aircraft: [Aircraft] { [a320, c172] }

    static let lufthansaLivery = AircraftLivery(
        aeroflyCode: "lufthansa",
        name: "Lufthansa",
        requirements: [],
        icaoCode: "DLH"
    )

    static let houseLivery = AircraftLivery(
        aeroflyCode: "default",
        name: "House Colors",
        requirements: [],
        icaoCode: nil
    )

    static var aircraftLiveries: [AircraftLiveryGroup] {
        [
            AircraftLiveryGroup(aeroflyCode: "a320_neo", liveries: [houseLivery, lufthansaLivery]),
            AircraftLiveryGroup(aeroflyCode: "c172", liveries: [])
        ]
    }
}
