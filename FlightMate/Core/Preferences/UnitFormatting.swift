//
//  UnitFormatting.swift
//  FlightMate
//
//  Display-time formatting for a `UnitSystem` preference. Every card/view
//  in the app should format through here rather than hand-rolling its own
//  "\(Int(x.rounded())) ft"-style string, so a unit preference change is
//  guaranteed to be reflected everywhere consistently.
//
//  Internal values passed in here are always in the aviation units
//  FlightMate computes in (feet, knots, nautical miles, feet/minute) --
//  this type only ever converts at the final display boundary, never
//  earlier in the pipeline.
//

import Foundation

enum UnitFormatting {
    static func altitude(feet: Double?, system: UnitSystem) -> String {
        guard let feet else { return "—" }
        switch system {
        case .imperial:
            return "\(Int(feet.rounded())) ft"
        case .metric:
            let meters = feet / UnitConversion.metersToFeet
            return "\(Int(meters.rounded())) m"
        }
    }

    static func speed(knots: Double?, system: UnitSystem) -> String {
        guard let knots else { return "—" }
        switch system {
        case .imperial:
            return "\(Int(knots.rounded())) kt"
        case .metric:
            let kilometersPerHour = knots * UnitConversion.knotsToKilometersPerHour
            return "\(Int(kilometersPerHour.rounded())) km/h"
        }
    }

    static func verticalSpeed(feetPerMinute: Double?, system: UnitSystem) -> String {
        guard let feetPerMinute else { return "—" }
        let sign = feetPerMinute >= 0 ? "+" : ""
        switch system {
        case .imperial:
            return "\(sign)\(Int(feetPerMinute.rounded())) fpm"
        case .metric:
            let metersPerMinute = feetPerMinute / UnitConversion.metersToFeet
            return "\(sign)\(Int(metersPerMinute.rounded())) m/min"
        }
    }

    static func distance(nauticalMiles: Double?, system: UnitSystem) -> String {
        guard let nauticalMiles else { return "—" }
        switch system {
        case .imperial:
            return String(format: "%.1f nm", nauticalMiles)
        case .metric:
            let kilometers = nauticalMiles * UnitConversion.nauticalMilesToKilometers
            return String(format: "%.1f km", kilometers)
        }
    }
}
