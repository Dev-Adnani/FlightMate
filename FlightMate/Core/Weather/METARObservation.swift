//
//  METARObservation.swift
//  FlightMate
//
//  Normalized METAR domain model (ported from Startgerät AviationWeatherApi).
//

import Foundation

struct METARCloudLayer: Equatable, Sendable {
    /// CLR / FEW / SCT / BKN / OVC
    let coverCode: String
    /// Feet AGL; nil when not reported.
    let baseFeetAGL: Double?
}

struct METARObservation: Equatable, Sendable {
    let icaoId: String
    let reportTime: Date?
    let temperatureCelsius: Double?
    let dewpointCelsius: Double?
    /// Degrees true; nil when variable (VRB).
    let windDirectionDegrees: Double?
    let windSpeedKnots: Double
    let windGustKnots: Double?
    /// Statute miles (capped at 10 when open-ended).
    let visibilityStatuteMiles: Double
    let clouds: [METARCloudLayer]
    /// Raw METAR text when available from SimBrief; AWC JSON may leave nil.
    let rawText: String?
}

enum FlightCategory: String, Equatable, Sendable {
    case vfr = "VFR"
    case mvfr = "MVFR"
    case ifr = "IFR"
    case lifr = "LIFR"

    /// US flight-category rules (Startgerät / Missionsgerät).
    static func us(visibilitySM: Double, ceilingFeet: Double?) -> FlightCategory {
        let ceiling = ceilingFeet ?? 9999
        if visibilitySM < 1 || ceiling < 500 { return .lifr }
        if visibilitySM < 3 || ceiling < 1000 { return .ifr }
        if visibilitySM <= 5 || ceiling <= 3000 { return .mvfr }
        return .vfr
    }
}
