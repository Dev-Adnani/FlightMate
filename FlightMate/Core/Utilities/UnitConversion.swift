//
//  UnitConversion.swift
//  FlightMate
//
//  Single source of truth for raw SI <-> aviation-unit conversion
//  constants. Previously duplicated (with slightly different precision)
//  across FlightAnalysisService and TelemetryCardModel -- consolidated
//  here so every collaborator that needs meters/knots math agrees on the
//  exact same constants.
//

import Foundation

/// Raw unit-conversion constants and helpers, independent of any
/// user-facing display preference (see `UnitFormatting` for
/// Imperial/Metric display formatting built on top of these).
enum UnitConversion {
    static let metersToFeet = 3.280839895
    static let metersPerSecondToKnots = 1.9438444924
    static let nauticalMilesToKilometers = 1.852
    static let knotsToKilometersPerHour = 1.852

    static func feet(fromMeters meters: Double) -> Double {
        meters * metersToFeet
    }

    static func knots(fromMetersPerSecond metersPerSecond: Double) -> Double {
        metersPerSecond * metersPerSecondToKnots
    }
}
