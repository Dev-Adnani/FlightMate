//
//  Runway.swift
//  FlightMate
//
//  Domain model for a single runway at an airport.
//
//  NOTE: The bundled reference data (sourced from fboes/aerofly-data) does
//  not currently include runway-level detail — only airport identifiers,
//  names, and coordinates. This model exists so `Airport.runways` has a
//  stable, typed shape ready to be populated from a future data source
//  (e.g. OurAirports' runways.csv) without changing any call sites.
//

import Foundation

/// A single runway belonging to an `Airport`.
struct Runway: Equatable, Hashable, Codable {
    /// Runway identifier, e.g. "09L/27R".
    let identifier: String

    /// Magnetic heading of the primary runway direction, in degrees.
    let headingDegrees: Double?

    /// Runway length, in feet.
    let lengthFt: Double?

    /// Runway width, in feet.
    let widthFt: Double?

    /// Surface type, e.g. "asphalt", "grass". Free-form, source-dependent.
    let surface: String?
}
