//
//  AirportCategory.swift
//  FlightMate
//
//  Airport classification as reported by the bundled reference data
//  (OurAirports' `type` taxonomy, as surfaced through Aerofly FS 4).
//

import Foundation

/// The kind of airfield, as classified by the reference data source.
enum AirportCategory: String, Codable, CaseIterable {
    case largeAirport = "large_airport"
    case mediumAirport = "medium_airport"
    case smallAirport = "small_airport"
    case largeAirbase = "large_airbase"
    case mediumAirbase = "medium_airbase"
    case smallAirbase = "small_airbase"
    case privateAirfield = "private_airfield"
    case heliport = "heliport"
    case closed = "closed"
}
