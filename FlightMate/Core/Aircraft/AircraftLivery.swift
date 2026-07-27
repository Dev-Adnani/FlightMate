//
//  AircraftLivery.swift
//  FlightMate
//
//  A paint scheme available for a given Aircraft.
//

import Foundation

/// A single livery (paint scheme) available for an `Aircraft`.
///
/// Decodes directly from an entry in the bundled `aircraft-liveries.json`
/// resource's `liveries` array.
struct AircraftLivery: Equatable, Hashable, Codable, Identifiable {
    /// Aerofly's internal identifier for this livery, e.g. "lufthansa".
    let aeroflyCode: String

    /// Display name, e.g. "Lufthansa".
    let name: String

    /// Aircraft feature/model requirements this livery depends on (e.g.
    /// winglet or engine variants), as reported by the source data.
    let requirements: [String]

    /// The airline's ICAO code, when the livery represents a real-world
    /// operator (e.g. "DLH" for Lufthansa). `nil` for liveries that don't
    /// map to a known airline (house colors, military, etc.).
    let icaoCode: String?

    var id: String { aeroflyCode }
}
