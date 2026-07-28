//
//  AirportCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model backing the reusable AirportCard
//  atom -- used three times by NavigationCard (departure/destination/
//  nearest), and reusable by any future screen that needs to show one
//  resolved airport (e.g. a future dedicated Airport Information feature).
//

import Foundation

/// Everything one instance of `AirportCard` needs to render, and nothing
/// else.
struct AirportCardModel: Identifiable, Equatable {
    enum Role: Equatable {
        case departure
        case destination
        case nearest

        var label: String {
            switch self {
            case .departure: return "Departure"
            case .destination: return "Destination"
            case .nearest: return "Nearest"
            }
        }

        var systemImage: String {
            switch self {
            case .departure: return "airplane.departure"
            case .destination: return "airplane.arrival"
            case .nearest: return "mappin.and.ellipse"
            }
        }
    }

    let role: Role
    let icaoCode: String?
    let airportName: String?
    /// Only ever populated for `.nearest` -- departure/destination don't
    /// have a meaningful "distance" of their own.
    let distanceNauticalMiles: Double?
    let isResolved: Bool

    var id: Role { role }

    /// `resolved == nil` means the session itself has no reference for
    /// this role yet (e.g. no destination set) -- distinct from a
    /// reference that exists but failed to resolve against bundled data.
    static func from(role: Role, resolved: ResolvedAirport?, distanceNauticalMiles: Double? = nil) -> AirportCardModel {
        AirportCardModel(
            role: role,
            icaoCode: resolved?.icaoCode,
            airportName: resolved?.airport?.name,
            distanceNauticalMiles: distanceNauticalMiles,
            isResolved: resolved?.status == .resolved
        )
    }
}
