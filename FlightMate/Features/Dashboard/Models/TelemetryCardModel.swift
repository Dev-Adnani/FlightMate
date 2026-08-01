//
//  TelemetryCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for TelemetryCard. Reads raw
//  altitude/ground speed/heading from FlightContext (the app's merged UDP +
//  main.mcf snapshot -- never raw UDP packets or main.mcf parsing
//  directly) since FlightAnalysis deliberately excludes telemetry
//  passthrough; vertical speed and connection health are genuinely
//  interpreted values and come from FlightAnalysis. TelemetryCard never
//  touches FlightContext or FlightAnalysis directly -- only this model.
//

import Foundation

/// Everything `TelemetryCard` needs to render, and nothing else.
struct TelemetryCardModel: Equatable {
    /// Always in aviation units internally (feet, knots) regardless of
    /// `unitSystem` -- only `TelemetryCard`'s display strings convert, via
    /// `UnitFormatting`, at the point of rendering.
    let altitudeFeet: Double?
    let groundSpeedKnots: Double?
    let headingDegrees: Double?
    let verticalSpeedFeetPerMinute: Double?
    let connectionHealthLevel: HealthLevel
    let connectionHealthLabel: String
    let unitSystem: UnitSystem

    static let empty = TelemetryCardModel(
        altitudeFeet: nil,
        groundSpeedKnots: nil,
        headingDegrees: nil,
        verticalSpeedFeetPerMinute: nil,
        connectionHealthLevel: .neutral,
        connectionHealthLabel: TelemetryHealth.notConnected.displayLabel,
        unitSystem: .imperial
    )

    static func from(context: FlightContext, analysis: FlightAnalysis, unitSystem: UnitSystem) -> TelemetryCardModel {
        TelemetryCardModel(
            altitudeFeet: context.altitudeMeters.map(UnitConversion.feet(fromMeters:)),
            groundSpeedKnots: context.groundSpeedMetersPerSecond.map(UnitConversion.knots(fromMetersPerSecond:)),
            headingDegrees: context.headingDegreesTrue,
            verticalSpeedFeetPerMinute: analysis.estimatedVerticalSpeedFeetPerMinute,
            connectionHealthLevel: analysis.telemetryHealth.healthLevel,
            connectionHealthLabel: analysis.telemetryHealth.displayLabel,
            unitSystem: unitSystem
        )
    }
}
