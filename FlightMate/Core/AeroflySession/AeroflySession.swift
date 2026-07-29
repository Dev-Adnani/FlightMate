//
//  AeroflySession.swift
//  FlightMate
//
//  A typed snapshot of everything FlightMate currently understands about
//  the simulator's active session, as read from main.mcf (and tm.log for
//  the version string plus live aircraft identity when present). Produced
//  by AeroflySessionMapper + AeroflySessionAircraftReconciler.
//
//  Source-of-truth note: this is a SESSION source, lower precedence than
//  live UDP telemetry. See FlightContext's doc header for the full
//  per-field precedence table (UDP > AeroflySession > bundled reference
//  data).
//

import Foundation

/// Everything known about the current Aerofly simulator session, parsed
/// from `main.mcf` (plus `aeroflyVersion` from `tm.log`).
///
/// All fields are optional: main.mcf's format can and will change across
/// Aerofly versions, and some fields (like `destination`) are only present
/// when the user has set up a flight plan. Missing values should be read
/// as "not currently known," never as an error — see
/// `AeroflySessionValidationReport` for *why* a field is missing.
struct AeroflySession: Equatable {
    /// The currently selected aircraft + livery, identified by their
    /// Aerofly codes (matching `Aircraft.aeroflyCode` /
    /// `AircraftLivery.aeroflyCode` in the reference data layer).
    struct AircraftSelection: Equatable {
        let aeroflyCode: String
        let liveryCode: String
    }

    /// A reference to an airport and, optionally, a specific runway at it.
    struct RunwayReference: Equatable {
        let airportCode: String
        let runwayIdentifier: String?
    }

    /// Session-configured weather, as set in Aerofly's flight setup UI.
    struct WeatherConditions: Equatable {
        let windStrengthFraction: Double?
        let windDirectionDegrees: Double?
        let turbulenceFraction: Double?
        let cumulusDensityFraction: Double?
        let cumulusHeightFraction: Double?
    }

    /// Simulated UTC date/time, as set in Aerofly's flight setup UI.
    struct SimulatedTime: Equatable {
        let year: Int?
        let month: Int?
        let day: Int?
        /// Fractional UTC hour of day (e.g. `13.5` == 13:30).
        let hours: Double?
    }

    /// Currently selected aircraft/livery. `nil` only if `main.mcf` is
    /// missing this group entirely (unexpected — see validation report).
    var aircraft: AircraftSelection?

    /// Initial lon/lat derived from `main.mcf`'s ECEF-style position
    /// vector (see `AeroflyPositionConverter`). Carries no altitude.
    /// Superseded by UDP telemetry the moment it's available.
    var initialPosition: GeoCoordinate?

    /// Whether the aircraft is configured to start on the ground.
    var onGround: Bool?

    /// Spawn/departure airport + runway. Always present in a normal
    /// session (Aerofly always records a spawn airport/runway even
    /// without a flight plan).
    var departure: RunwayReference?

    /// Destination airport + runway, parsed from `navigation.Route.Ways`
    /// when a flight plan is set. `nil` (never fabricated) when no flight
    /// plan exists.
    var destination: RunwayReference?

    /// Session-configured weather.
    var weather: WeatherConditions?

    /// Session-configured simulated time.
    var simulatedTime: SimulatedTime?

    /// The running Aerofly FS 4 version (e.g. `"4.08.04.01"`), read from
    /// `tm.log`. `nil` if unreadable — never guessed.
    var aeroflyVersion: String?
}
