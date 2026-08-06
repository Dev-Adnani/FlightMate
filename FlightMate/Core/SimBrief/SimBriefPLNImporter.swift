//
//  SimBriefPLNImporter.swift
//  FlightMate
//
//  Imports MSFS-style PLN XML (SimBrief / Missionsgerät MsfsPln subset).
//

import Foundation

enum SimBriefPLNImporterError: Error, LocalizedError {
    case invalidXML
    case missingAirports

    var errorDescription: String? {
        switch self {
        case .invalidXML: return "Could not parse PLN XML."
        case .missingAirports: return "PLN is missing departure or destination."
        }
    }
}

enum SimBriefPLNImporter {
    static func importPLN(data: Data) throws -> SimBriefOFP {
        let xml = try XMLDocument(data: data, options: [.documentTidyXML])
        guard let root = xml.rootElement() else { throw SimBriefPLNImporterError.invalidXML }

        let waypoints = (try? root.nodes(forXPath: ".//ATCWaypoint")) as? [XMLElement] ?? []
        var parsed: [(id: String, lat: Double, lon: Double, type: String)] = []

        for wp in waypoints {
            let id = wp.attribute(forName: "id")?.stringValue ?? ""
            let type = (wp.elements(forName: "ATCWaypointType").first?.stringValue ?? "User").lowercased()
            guard let world = wp.elements(forName: "WorldPosition").first?.stringValue,
                  let coord = parseWorldPosition(world)
            else { continue }
            parsed.append((id, coord.lat, coord.lon, type))
        }

        guard let first = parsed.first, let last = parsed.last else {
            throw SimBriefPLNImporterError.missingAirports
        }

        let origin = SimBriefAirport(
            icao: first.id,
            name: nil,
            latitude: first.lat,
            longitude: first.lon,
            elevationFeet: nil,
            plannedRunway: nil,
            metarRaw: nil
        )
        let destination = SimBriefAirport(
            icao: last.id,
            name: nil,
            latitude: last.lat,
            longitude: last.lon,
            elevationFeet: nil,
            plannedRunway: nil,
            metarRaw: nil
        )

        let wps = parsed.map { item -> SimBriefWaypoint in
            let kind: SimBriefWaypoint.Kind
            switch item.type {
            case "airport": kind = .airport
            case "vor", "ndb": kind = .navaid
            case "intersection", "user": kind = .waypoint
            default: kind = .other
            }
            return SimBriefWaypoint(
                identifier: item.id,
                latitude: item.lat,
                longitude: item.lon,
                altitudeFeet: nil,
                kind: kind
            )
        }

        return SimBriefOFP(
            origin: origin,
            destination: destination,
            waypoints: wps,
            cruiseAltitudeFeet: nil,
            cruiseSpeedKnots: nil,
            aircraftICAO: nil,
            airlineICAO: nil,
            scheduledOut: nil,
            routeString: wps.map(\.identifier).joined(separator: " ")
        )
    }

    /// MSFS WorldPosition: "N47° 27' 59.99\",E8° 32' 60.00\",+000141.00"
    private static func parseWorldPosition(_ text: String) -> (lat: Double, lon: Double)? {
        let parts = text.split(separator: ",").map(String.init)
        guard parts.count >= 2,
              let lat = parseDMS(parts[0]),
              let lon = parseDMS(parts[1])
        else { return nil }
        return (lat, lon)
    }

    private static func parseDMS(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let hemi = trimmed.first else { return nil }
        let sign: Double
        switch hemi {
        case "N", "E": sign = 1
        case "S", "W": sign = -1
        default: return nil
        }
        let body = trimmed.dropFirst()
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "°", with: " ")
            .replacingOccurrences(of: "'", with: " ")
        let nums = body.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .compactMap { Double($0) }
        guard nums.count >= 1 else { return nil }
        let deg = nums[0]
        let min = nums.count > 1 ? nums[1] : 0
        let sec = nums.count > 2 ? nums[2] : 0
        return sign * (deg + min / 60 + sec / 3600)
    }
}
