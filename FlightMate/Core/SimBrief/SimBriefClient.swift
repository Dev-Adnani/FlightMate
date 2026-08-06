//
//  SimBriefClient.swift
//  FlightMate
//
//  Fetches latest OFP JSON from SimBrief (Startgerät SimBriefApi).
//

import Foundation

protocol SimBriefFetching: Sendable {
    func fetchOFP(usernameOrUserID: String) async throws -> SimBriefOFP
}

struct SimBriefClient: SimBriefFetching, Sendable {
    private let http: HTTPClient

    nonisolated init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    nonisolated func fetchOFP(usernameOrUserID: String) async throws -> SimBriefOFP {
        let trimmed = usernameOrUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HTTPClientError.invalidURL }

        var components = URLComponents(string: "https://www.simbrief.com/api/xml.fetcher.php")!
        let isNumeric = trimmed.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        components.queryItems = [
            URLQueryItem(name: isNumeric ? "userid" : "username", value: trimmed),
            URLQueryItem(name: "json", value: "v2"),
        ]
        guard let url = components.url else { throw HTTPClientError.invalidURL }

        let data = try await http.get(url: url)
        let decoder = JSONDecoder()
        let payload: SimBriefAPIPayload
        do {
            payload = try decoder.decode(SimBriefAPIPayload.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        }
        return payload.toOFP()
    }
}

// MARK: - API payload (subset)

struct SimBriefAPIPayload: Decodable {
    struct General: Decodable {
        let initial_altitude: String?
        let icao_airline: String?
        let cruise_tas: String?
    }

    struct Airport: Decodable {
        let icao_code: String
        let pos_lat: String
        let pos_long: String
        let elevation: String?
        let name: String?
        let plan_rwy: String?
        let metar: String?
    }

    struct NavlogItem: Decodable {
        let ident: String
        let type: String?
        let pos_lat: String
        let pos_long: String
        let altitude_feet: String?
    }

    struct Aircraft: Decodable {
        let icaocode: String?
    }

    struct Times: Decodable {
        let sched_out: String?
    }

    let general: General?
    let origin: Airport
    let destination: Airport
    let navlog: [NavlogItem]?
    let aircraft: Aircraft?
    let times: Times?

    func toOFP() -> SimBriefOFP {
        func airport(_ a: Airport) -> SimBriefAirport {
            SimBriefAirport(
                icao: a.icao_code,
                name: a.name,
                latitude: Double(a.pos_lat) ?? 0,
                longitude: Double(a.pos_long) ?? 0,
                elevationFeet: a.elevation.flatMap(Double.init),
                plannedRunway: a.plan_rwy,
                metarRaw: a.metar
            )
        }

        let originAP = airport(origin)
        let destAP = airport(destination)

        var wps: [SimBriefWaypoint] = [
            SimBriefWaypoint(
                identifier: originAP.icao,
                latitude: originAP.latitude,
                longitude: originAP.longitude,
                altitudeFeet: originAP.elevationFeet,
                kind: .airport
            ),
        ]
        if let rwy = originAP.plannedRunway, !rwy.isEmpty {
            wps.append(SimBriefWaypoint(
                identifier: rwy,
                latitude: originAP.latitude,
                longitude: originAP.longitude,
                altitudeFeet: originAP.elevationFeet,
                kind: .runway
            ))
        }

        let navItems = (navlog ?? []).filter { $0.type != "ltlg" }
        for item in navItems.dropLast() {
            let kind: SimBriefWaypoint.Kind
            switch item.type {
            case "vor": kind = .navaid
            case "apt": kind = .airport
            case "wpt": kind = .waypoint
            default: kind = .other
            }
            wps.append(SimBriefWaypoint(
                identifier: item.ident,
                latitude: Double(item.pos_lat) ?? 0,
                longitude: Double(item.pos_long) ?? 0,
                altitudeFeet: item.altitude_feet.flatMap(Double.init),
                kind: kind
            ))
        }

        if let rwy = destAP.plannedRunway, !rwy.isEmpty {
            wps.append(SimBriefWaypoint(
                identifier: rwy,
                latitude: destAP.latitude,
                longitude: destAP.longitude,
                altitudeFeet: destAP.elevationFeet,
                kind: .runway
            ))
        }
        wps.append(SimBriefWaypoint(
            identifier: destAP.icao,
            latitude: destAP.latitude,
            longitude: destAP.longitude,
            altitudeFeet: destAP.elevationFeet,
            kind: .airport
        ))

        let route = wps.map(\.identifier).joined(separator: " ")
        let sched = times?.sched_out.flatMap { ISO8601DateFormatter().date(from: $0) }

        return SimBriefOFP(
            origin: originAP,
            destination: destAP,
            waypoints: wps,
            cruiseAltitudeFeet: general?.initial_altitude.flatMap(Double.init),
            cruiseSpeedKnots: general?.cruise_tas.flatMap(Double.init),
            aircraftICAO: aircraft?.icaocode,
            airlineICAO: general?.icao_airline,
            scheduledOut: sched,
            routeString: route
        )
    }
}
