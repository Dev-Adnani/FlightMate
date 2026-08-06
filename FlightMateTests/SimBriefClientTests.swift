//
//  SimBriefClientTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct SimBriefClientTests {
    @Test func decodesMinimalOFPPayload() throws {
        let json = """
        {
          "general": { "initial_altitude": "35000", "icao_airline": "AAL", "cruise_tas": "450" },
          "origin": {
            "icao_code": "KJFK", "pos_lat": "40.64", "pos_long": "-73.78",
            "elevation": "13", "name": "Kennedy", "plan_rwy": "31L", "metar": "KJFK 010000Z"
          },
          "destination": {
            "icao_code": "KLAX", "pos_lat": "33.94", "pos_long": "-118.41",
            "elevation": "128", "name": "Los Angeles", "plan_rwy": "25L", "metar": ""
          },
          "navlog": [
            { "ident": "KJFK", "type": "apt", "pos_lat": "40.64", "pos_long": "-73.78", "altitude_feet": "13" },
            { "ident": "FIX1", "type": "wpt", "pos_lat": "40.0", "pos_long": "-100.0", "altitude_feet": "35000" },
            { "ident": "KLAX", "type": "apt", "pos_lat": "33.94", "pos_long": "-118.41", "altitude_feet": "128" }
          ],
          "aircraft": { "icaocode": "B738" },
          "times": { "sched_out": "2026-08-07T12:00:00Z" }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(SimBriefAPIPayload.self, from: json)
        let ofp = payload.toOFP()
        #expect(ofp.origin.icao == "KJFK")
        #expect(ofp.destination.icao == "KLAX")
        #expect(ofp.cruiseAltitudeFeet == 35000)
        #expect(ofp.waypoints.contains(where: { $0.identifier == "FIX1" }))
    }

    @Test func plnImporterParsesWorldPosition() throws {
        let pln = """
        <?xml version="1.0"?>
        <SimBase.Document>
          <FlightPlan.FlightPlan>
            <ATCWaypoint id="KJFK"><ATCWaypointType>Airport</ATCWaypointType>
              <WorldPosition>N40° 38' 24.00",W73° 46' 48.00",+000013.00</WorldPosition>
            </ATCWaypoint>
            <ATCWaypoint id="KLAX"><ATCWaypointType>Airport</ATCWaypointType>
              <WorldPosition>N33° 56' 24.00",W118° 24' 36.00",+000128.00</WorldPosition>
            </ATCWaypoint>
          </FlightPlan.FlightPlan>
        </SimBase.Document>
        """.data(using: .utf8)!
        let ofp = try SimBriefPLNImporter.importPLN(data: pln)
        #expect(ofp.origin.icao == "KJFK")
        #expect(ofp.destination.icao == "KLAX")
        #expect(ofp.waypoints.count == 2)
    }
}

struct FakeHTTPClient: HTTPClient {
    var data: Data = Data()
    func get(url: URL) async throws -> Data { data }
}
