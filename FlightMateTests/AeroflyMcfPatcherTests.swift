//
//  AeroflyMcfPatcherTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct AeroflyMcfPatcherTests {
    @Test func serializerRoundTripsParseableTree() throws {
        let text = AeroflySessionFixtures.mainMcf(includeFlightPlan: true)
        let root = try AeroflyMcfParser.parse(text)
        let serialized = AeroflyMcfSerializer.serialize(root)
        let again = try AeroflyMcfParser.parse(serialized)
        #expect(again.type == "file")
        #expect(again.firstChild(type: "tmsettings_sim") != nil)
    }

    @Test func applyingWeatherPatchesWindAndClouds() throws {
        let text = AeroflySessionFixtures.mainMcf()
        let root = try AeroflyMcfParser.parse(text)
        let weather = AeroflyEditableWeather(
            windDirectionDegrees: 180,
            windSpeedKnots: 20,
            windGustKnots: 25,
            temperatureCelsius: 10,
            visibilityStatuteMiles: 5,
            clouds: [.init(coverFraction: 1, heightFeetAGL: 1500)]
        )
        let patched = try AeroflyMcfPatcher.applying(weather: weather, to: root)
        let sim = try #require(patched.firstChild(type: "tmsettings_sim"))
        let wind = try #require(sim.firstChild(type: "tmsettings_wind"))
        #expect(wind.firstChild(key: "direction_in_degree")?.doubleValue == 180)
        #expect(sim.firstChild(key: "visibility") != nil)
    }

    @Test func applyingRouteRebuildsWays() throws {
        let text = AeroflySessionFixtures.mainMcf()
        let root = try AeroflyMcfParser.parse(text)
        let ofp = SimBriefOFP(
            origin: SimBriefAirport(
                icao: "KJFK",
                name: nil,
                latitude: 40.64,
                longitude: -73.78,
                elevationFeet: 13,
                plannedRunway: "31L",
                metarRaw: nil
            ),
            destination: SimBriefAirport(
                icao: "KLAX",
                name: nil,
                latitude: 33.94,
                longitude: -118.41,
                elevationFeet: 128,
                plannedRunway: "25L",
                metarRaw: nil
            ),
            waypoints: [
                SimBriefWaypoint(identifier: "KJFK", latitude: 40.64, longitude: -73.78, altitudeFeet: 13, kind: .airport),
                SimBriefWaypoint(identifier: "31L", latitude: 40.64, longitude: -73.78, altitudeFeet: 13, kind: .runway),
                SimBriefWaypoint(identifier: "FIX1", latitude: 40.0, longitude: -90.0, altitudeFeet: 35000, kind: .waypoint),
                SimBriefWaypoint(identifier: "25L", latitude: 33.94, longitude: -118.41, altitudeFeet: 128, kind: .runway),
                SimBriefWaypoint(identifier: "KLAX", latitude: 33.94, longitude: -118.41, altitudeFeet: 128, kind: .airport),
            ],
            cruiseAltitudeFeet: 35000,
            cruiseSpeedKnots: 450,
            aircraftICAO: "B738",
            airlineICAO: nil,
            scheduledOut: nil,
            routeString: "KJFK 31L FIX1 25L KLAX"
        )
        let patched = try AeroflyMcfPatcher.applying(route: ofp, to: root)
        let ways = patched
            .firstChild(type: "tmsettings_sim")?
            .firstChild(type: "tmnavigation_config")?
            .firstChild(type: "tmnav_route")?
            .firstChild(type: "pointer_list_tmnav_route_way")
        #expect(ways?.children.count == 5)
        #expect(ways?.firstChild(type: "tmnav_route_origin")?.key == "KJFK")
        #expect(ways?.firstChild(type: "tmnav_route_destination")?.key == "KLAX")
    }
}
