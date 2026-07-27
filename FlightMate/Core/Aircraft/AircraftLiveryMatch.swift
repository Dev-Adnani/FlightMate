//
//  AircraftLiveryMatch.swift
//  FlightMate
//
//  Result type for looking up liveries by airline ICAO code across all
//  aircraft (a livery alone doesn't identify which aircraft it belongs to).
//

import Foundation

/// A livery paired with the identifier of the aircraft it belongs to.
struct AircraftLiveryMatch: Equatable, Hashable {
    /// `Aircraft.aeroflyCode` of the owning aircraft.
    let aircraftId: String
    let livery: AircraftLivery
}
