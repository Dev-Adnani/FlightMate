//
//  Aircraft.swift
//  FlightMate
//
//  Domain model describing an aircraft type available in Aerofly FS 4 and
//  its performance characteristics.
//

import Foundation

/// Represents an aircraft type known to Aerofly FS 4.
///
/// Decodes directly from the bundled `aircraft-liveries.json` resource
/// (sourced from fboes/aerofly-data). That file's `liveries` array is
/// intentionally not decoded here — this model stays lean; liveries are
/// looked up separately via `AircraftService.liveries(for:)`.
struct Aircraft: Equatable, Hashable, Codable, Identifiable {
    /// Aerofly's internal identifier, e.g. "a320_neo". Used as the stable identity.
    let aeroflyCode: String

    /// Short display name, e.g. "A320neo".
    let name: String

    /// Full display name, e.g. "Airbus A320neo".
    let nameFull: String

    /// ICAO type designator, e.g. "A20N".
    let icaoCode: String

    /// Free-form capability/category tags, e.g. "airliner", "retractable_gear".
    let tags: [String]

    let approachAirspeedKts: Double
    let cruiseAltitudeFt: Double
    let cruiseSpeedKts: Double
    let maximumRangeNm: Double
    let maximumLoadRangeNm: Double
    let maximumFuelRangeNm: Double
    let maximumFerryRangeNm: Double

    let maximumFuelMassKg: Double?
    let maximumPayloadKg: Double?
    let maximumTakeoffMassKg: Double?
    let operatingEmptyMassKg: Double?
    let maximumPersonsOnBoard: Int?

    var id: String { aeroflyCode }

    /// Broad grouping derived from `tags` — see `AircraftCategory`.
    var category: AircraftCategory { AircraftCategory(tags: tags) }
}
