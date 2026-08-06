//
//  AeroflyMcfPatcher.swift
//  FlightMate
//
//  Pure tree patches for weather and navigation into a parsed main.mcf.
//  Field layout mirrors Missionsgerät MainMcfExport.
//

import Foundation

enum AeroflyMcfPatcher {
    /// Patches wind, clouds, and visibility under `tmsettings_sim`.
    static func applying(weather: AeroflyEditableWeather, to root: AeroflyMcfNode) throws -> AeroflyMcfNode {
        guard root.type == "file",
              let sim = root.firstChild(type: "tmsettings_sim")
        else {
            throw AeroflyMcfWriterError.unexpectedStructure("Missing tmsettings_sim")
        }

        let fractions = weather.mcfFractions()
        let wind = AeroflyMcfNode(
            type: "tmsettings_wind",
            key: "wind",
            value: "",
            children: [
                leaf("float64", "strength", fractions.windStrength),
                leaf("float64", "direction_in_degree", fractions.windDirectionDegrees),
                leaf("float64", "turbulence", fractions.turbulence),
                leaf("float64", "thermal_activity", fractions.thermalActivity),
            ]
        )
        let clouds = AeroflyMcfNode(
            type: "tmsettings_clouds",
            key: "clouds",
            value: "",
            children: [
                leaf("float64", "cumulus_density", fractions.cumulusDensity),
                leaf("float64", "cumulus_height", fractions.cumulusHeight),
                leaf("float64", "cumulus_mediocris_density", fractions.mediocrisDensity),
                leaf("float64", "cumulus_mediocris_height", fractions.mediocrisHeight),
                leaf("float64", "cirrus_density", fractions.cirrusDensity),
                leaf("float64", "cirrus_height", fractions.cirrusHeight),
            ]
        )
        let visibility = leaf("float64", "visibility", fractions.visibility)

        var nextSim = sim
            .replacingOrAppendingChild(type: "tmsettings_wind", with: wind)
            .replacingOrAppendingChild(type: "tmsettings_clouds", with: clouds)
            .replacingOrAppendingChild(key: "visibility", with: visibility)

        return root.replacingOrAppendingChild(type: "tmsettings_sim", with: nextSim)
    }

    /// Rebuilds navigation Route/Ways from a SimBrief (or PLN) OFP.
    static func applying(route ofp: SimBriefOFP, to root: AeroflyMcfNode) throws -> AeroflyMcfNode {
        guard root.type == "file",
              let sim = root.firstChild(type: "tmsettings_sim")
        else {
            throw AeroflyMcfWriterError.unexpectedStructure("Missing tmsettings_sim")
        }

        var wayNodes: [AeroflyMcfNode] = []
        for (index, wp) in ofp.waypoints.enumerated() {
            let typeName: String
            switch wp.kind {
            case .airport:
                if index == 0 { typeName = "tmnav_route_origin" }
                else if index == ofp.waypoints.count - 1 { typeName = "tmnav_route_destination" }
                else { typeName = "tmnav_route_waypoint" }
            case .runway:
                if index <= 1 { typeName = "tmnav_route_departure_runway" }
                else { typeName = "tmnav_route_destination_runway" }
            default:
                typeName = "tmnav_route_waypoint"
            }

            let altM = (wp.altitudeFeet ?? 0) / 3.28084
            let ecef = AeroflyPositionConverter.position(
                latitude: wp.latitude,
                longitude: wp.longitude,
                altitudeMeters: altM
            )
            let positionValue = ecef.map { String($0) }.joined(separator: " ")
            wayNodes.append(
                AeroflyMcfNode(
                    type: typeName,
                    key: wp.identifier,
                    value: "\(index)",
                    children: [
                        AeroflyMcfNode(type: "string8u", key: "Identifier", value: wp.identifier, children: []),
                        AeroflyMcfNode(type: "vector3_float64", key: "Position", value: positionValue, children: []),
                    ]
                )
            )
        }

        let cruise = ofp.cruiseAltitudeFeet.map { $0 / 3.28084 } ?? -1
        let ways = AeroflyMcfNode(
            type: "pointer_list_tmnav_route_way",
            key: "Ways",
            value: "",
            children: wayNodes
        )
        let route = AeroflyMcfNode(
            type: "tmnav_route",
            key: "Route",
            value: "",
            children: [
                leaf("float64", "CruiseAltitude", cruise),
                ways,
            ]
        )
        let navigation = AeroflyMcfNode(
            type: "tmnavigation_config",
            key: "navigation",
            value: "",
            children: [route]
        )

        // Also set departure airport on flight_setting when present.
        var nextSim = sim.replacingOrAppendingChild(type: "tmnavigation_config", with: navigation)
        if var flight = sim.firstChild(type: "tmsettings_flight") {
            flight = flight.replacingOrAppendingChild(
                key: "airport",
                with: AeroflyMcfNode(type: "string8u", key: "airport", value: ofp.origin.icao, children: [])
            )
            if let rwy = ofp.origin.plannedRunway {
                flight = flight.replacingOrAppendingChild(
                    key: "runway",
                    with: AeroflyMcfNode(type: "string8u", key: "runway", value: rwy, children: [])
                )
            }
            let altM = (ofp.origin.elevationFeet ?? 0) / 3.28084
            let ecef = AeroflyPositionConverter.position(
                latitude: ofp.origin.latitude,
                longitude: ofp.origin.longitude,
                altitudeMeters: altM
            )
            flight = flight.replacingOrAppendingChild(
                key: "position",
                with: AeroflyMcfNode(
                    type: "vector3_float64",
                    key: "position",
                    value: ecef.map { String($0) }.joined(separator: " "),
                    children: []
                )
            )
            nextSim = nextSim.replacingOrAppendingChild(type: "tmsettings_flight", with: flight)
        }

        return root.replacingOrAppendingChild(type: "tmsettings_sim", with: nextSim)
    }

    private static func leaf(_ type: String, _ key: String, _ value: Double) -> AeroflyMcfNode {
        AeroflyMcfNode(type: type, key: key, value: String(value), children: [])
    }
}
