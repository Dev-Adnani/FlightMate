//
//  SimBriefOFP.swift
//  FlightMate
//
//  Domain model for a SimBrief operational flight plan (fields we use).
//  Shape aligned with Startgerät SimBriefApiPayload.
//

import Foundation

struct SimBriefWaypoint: Equatable, Sendable, Identifiable {
    var id: String { "\(identifier)-\(latitude)-\(longitude)" }
    let identifier: String
    let latitude: Double
    let longitude: Double
    let altitudeFeet: Double?
    let kind: Kind

    enum Kind: String, Equatable, Sendable {
        case airport
        case runway
        case waypoint
        case navaid
        case other
    }
}

struct SimBriefAirport: Equatable, Sendable {
    let icao: String
    let name: String?
    let latitude: Double
    let longitude: Double
    let elevationFeet: Double?
    let plannedRunway: String?
    let metarRaw: String?
}

struct SimBriefOFP: Equatable, Sendable {
    let origin: SimBriefAirport
    let destination: SimBriefAirport
    let waypoints: [SimBriefWaypoint]
    let cruiseAltitudeFeet: Double?
    let cruiseSpeedKnots: Double?
    let aircraftICAO: String?
    let airlineICAO: String?
    let scheduledOut: Date?
    let routeString: String

    var distanceSummary: String {
        "\(origin.icao) → \(destination.icao)"
    }
}

enum SimBriefWeatherOnImport: Int, CaseIterable, Identifiable, Sendable {
    case none = -1
    case origin = 0
    case destination = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "Do not use SimBrief weather"
        case .origin: return "Use SimBrief origin weather"
        case .destination: return "Use SimBrief destination weather"
        }
    }
}
