//
//  AircraftLiveryGroup.swift
//  FlightMate
//
//  DTO for decoding the `liveries` array out of `aircraft-liveries.json`
//  independently of the Aircraft model (which intentionally omits liveries).
//

import Foundation

/// The liveries available for a single aircraft, keyed by that aircraft's
/// `aeroflyCode`.
///
/// Decodes from the same `aircraft-liveries.json` entries as `Aircraft`,
/// picking out only the `aeroflyCode` and `liveries` fields and ignoring
/// the rest (performance/mass fields belong to `Aircraft`).
struct AircraftLiveryGroup: Decodable {
    let aeroflyCode: String
    let liveries: [AircraftLivery]
}
