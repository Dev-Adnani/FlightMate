//
//  AircraftDecodingTests.swift
//  FlightMateTests
//
//  Verifies Aircraft decodes the source data shape used by the bundled
//  aircraft-liveries.json resource, including optional performance fields
//  and its (intentionally ignored) `liveries` array.
//

import Foundation
import Testing
@testable import FlightMate

struct AircraftDecodingTests {

    @Test func decodesSourceShapedJSONWithOptionalFields() throws {
        let json = """
        {
            "aeroflyCode": "a320_neo",
            "name": "A320neo",
            "nameFull": "Airbus A320neo",
            "icaoCode": "A20N",
            "tags": ["airplane", "airliner", "jet"],
            "approachAirspeedKts": 136,
            "cruiseAltitudeFt": 32000,
            "cruiseSpeedKts": 453,
            "maximumRangeNm": 3400,
            "maximumLoadRangeNm": 2450,
            "maximumFuelRangeNm": 3400,
            "maximumFerryRangeNm": 4300,
            "maximumFuelMassKg": 19050.9,
            "maximumPayloadKg": 21000,
            "maximumTakeoffMassKg": 79000,
            "operatingEmptyMassKg": 44300,
            "maximumPersonsOnBoard": 201
        }
        """.data(using: .utf8)!

        let aircraft = try JSONDecoder().decode(Aircraft.self, from: json)

        #expect(aircraft.aeroflyCode == "a320_neo")
        #expect(aircraft.id == "a320_neo")
        #expect(aircraft.icaoCode == "A20N")
        #expect(aircraft.tags == ["airplane", "airliner", "jet"])
        #expect(aircraft.maximumPersonsOnBoard == 201)
    }

    @Test func decodesWithMissingOptionalFields() throws {
        // Mirrors gliders/GA aircraft in the source data that omit mass fields.
        let json = """
        {
            "aeroflyCode": "glider",
            "name": "Glider",
            "nameFull": "Test Glider",
            "icaoCode": "GLID",
            "tags": ["glider"],
            "approachAirspeedKts": 45,
            "cruiseAltitudeFt": 5000,
            "cruiseSpeedKts": 60,
            "maximumRangeNm": 200,
            "maximumLoadRangeNm": 200,
            "maximumFuelRangeNm": 200,
            "maximumFerryRangeNm": 200
        }
        """.data(using: .utf8)!

        let aircraft = try JSONDecoder().decode(Aircraft.self, from: json)

        #expect(aircraft.maximumFuelMassKg == nil)
        #expect(aircraft.maximumPayloadKg == nil)
        #expect(aircraft.maximumTakeoffMassKg == nil)
        #expect(aircraft.operatingEmptyMassKg == nil)
        #expect(aircraft.maximumPersonsOnBoard == nil)
    }

    @Test func decodesAndIgnoresLiveriesArrayFromAircraftLiveriesJSONShape() throws {
        // aircraft-liveries.json entries carry a `liveries` array alongside
        // the same fields as the old aircraft.json. Aircraft must decode
        // cleanly from this shape while staying lean (no liveries property).
        let json = """
        {
            "aeroflyCode": "a320_neo",
            "name": "A320neo",
            "nameFull": "Airbus A320neo",
            "icaoCode": "A20N",
            "tags": ["airplane", "airliner", "jet"],
            "approachAirspeedKts": 136,
            "cruiseAltitudeFt": 32000,
            "cruiseSpeedKts": 453,
            "maximumRangeNm": 3400,
            "maximumLoadRangeNm": 2450,
            "maximumFuelRangeNm": 3400,
            "maximumFerryRangeNm": 4300,
            "liveries": [
                { "aeroflyCode": "default", "name": "House Colors", "requirements": [] },
                { "aeroflyCode": "lufthansa", "name": "Lufthansa", "requirements": [], "icaoCode": "DLH" }
            ]
        }
        """.data(using: .utf8)!

        let aircraft = try JSONDecoder().decode(Aircraft.self, from: json)

        #expect(aircraft.aeroflyCode == "a320_neo")
    }

    @Test func categoryIsDerivedFromTagsWithSourcePriorityOrder() throws {
        #expect(ReferenceDataFixtures.a320.category == .airliner)
        #expect(ReferenceDataFixtures.c172.category == .generalAviation)
    }
}
