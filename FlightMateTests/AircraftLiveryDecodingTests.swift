//
//  AircraftLiveryDecodingTests.swift
//  FlightMateTests
//
//  Verifies AircraftLivery and AircraftLiveryGroup decode the shape used by
//  the bundled aircraft-liveries.json resource.
//

import Foundation
import Testing
@testable import FlightMate

struct AircraftLiveryDecodingTests {

    @Test func decodesLiveryWithICAOCode() throws {
        let json = """
        { "aeroflyCode": "lufthansa", "name": "Lufthansa", "requirements": [], "icaoCode": "DLH" }
        """.data(using: .utf8)!

        let livery = try JSONDecoder().decode(AircraftLivery.self, from: json)

        #expect(livery.aeroflyCode == "lufthansa")
        #expect(livery.name == "Lufthansa")
        #expect(livery.icaoCode == "DLH")
        #expect(livery.id == "lufthansa")
    }

    @Test func decodesLiveryWithoutICAOCode() throws {
        // House-color / non-airline liveries omit icaoCode in the source data.
        let json = """
        { "aeroflyCode": "default", "name": "House Colors", "requirements": ["winglets"] }
        """.data(using: .utf8)!

        let livery = try JSONDecoder().decode(AircraftLivery.self, from: json)

        #expect(livery.icaoCode == nil)
        #expect(livery.requirements == ["winglets"])
    }

    @Test func decodesLiveryGroupIgnoringUnrelatedAircraftFields() throws {
        let json = """
        {
            "aeroflyCode": "a320_neo",
            "name": "A320neo",
            "nameFull": "Airbus A320neo",
            "icaoCode": "A20N",
            "tags": ["airplane", "airliner", "jet"],
            "approachAirspeedKts": 136,
            "liveries": [
                { "aeroflyCode": "default", "name": "House Colors", "requirements": [] },
                { "aeroflyCode": "lufthansa", "name": "Lufthansa", "requirements": [], "icaoCode": "DLH" }
            ]
        }
        """.data(using: .utf8)!

        let group = try JSONDecoder().decode(AircraftLiveryGroup.self, from: json)

        #expect(group.aeroflyCode == "a320_neo")
        #expect(group.liveries.count == 2)
        #expect(group.liveries.last?.icaoCode == "DLH")
    }
}
