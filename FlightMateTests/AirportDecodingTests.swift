//
//  AirportDecodingTests.swift
//  FlightMateTests
//
//  Verifies Airport decodes a single GeoJSON Feature, matching the shape
//  used by the bundled airports.geojson resource.
//

import Foundation
import Testing
@testable import FlightMate

struct AirportDecodingTests {

    @Test func decodesGeoJSONFeature() throws {
        let json = """
        {
            "type": "Feature",
            "geometry": { "type": "Point", "coordinates": [-122.374821, 37.619806, 4.0] },
            "properties": {
                "title": "KSFO",
                "type": "large_airport",
                "description": "San Francisco International Airport",
                "elevation": 13,
                "municipality": "San Francisco"
            }
        }
        """.data(using: .utf8)!

        let airport = try JSONDecoder().decode(Airport.self, from: json)

        #expect(airport.icaoCode == "KSFO")
        #expect(airport.name == "San Francisco International Airport")
        #expect(airport.latitude == 37.619806)
        #expect(airport.longitude == -122.374821)
        #expect(airport.elevationFt == 13)
        #expect(airport.municipality == "San Francisco")
        #expect(airport.category == .largeAirport)
        #expect(airport.runways.isEmpty)
        #expect(airport.id == "KSFO")
    }

    @Test func decodesFeatureCollectionFeaturesArray() throws {
        let json = """
        [
            {
                "type": "Feature",
                "geometry": { "type": "Point", "coordinates": [-117.670666, 34.566631] },
                "properties": { "title": "04CA", "type": "small_airport", "description": "Gray Butte Field" }
            },
            {
                "type": "Feature",
                "geometry": { "type": "Point", "coordinates": [-80.274803, 25.325399] },
                "properties": { "title": "07FA", "type": "private_airfield", "description": "Ocean Reef Club Airport" }
            }
        ]
        """.data(using: .utf8)!

        let airports = try JSONDecoder().decode([Airport].self, from: json)

        #expect(airports.count == 2)
        #expect(airports[0].icaoCode == "04CA")
        #expect(airports[1].icaoCode == "07FA")
        #expect(airports[1].category == .privateAirfield)
    }

    @Test func toleratesMissingOptionalProperties() throws {
        let json = """
        {
            "type": "Feature",
            "geometry": { "type": "Point", "coordinates": [1.0, 2.0] },
            "properties": { "title": "TEST", "description": "Test Field" }
        }
        """.data(using: .utf8)!

        let airport = try JSONDecoder().decode(Airport.self, from: json)

        #expect(airport.elevationFt == nil)
        #expect(airport.municipality == nil)
        #expect(airport.category == nil)
    }

    @Test func treatsUnrecognizedCategoryAsNil() throws {
        let json = """
        {
            "type": "Feature",
            "geometry": { "type": "Point", "coordinates": [1.0, 2.0] },
            "properties": { "title": "TEST", "type": "some_future_category", "description": "Test Field" }
        }
        """.data(using: .utf8)!

        let airport = try JSONDecoder().decode(Airport.self, from: json)

        #expect(airport.category == nil)
    }

    @Test func coordinateMatchesLatitudeAndLongitude() {
        let airport = Airport(icaoCode: "TEST", name: "Test Field", latitude: 1.5, longitude: -2.5)

        #expect(airport.coordinate == GeoCoordinate(latitude: 1.5, longitude: -2.5))
    }
}
