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
    private static let metersToFeet = 3.280839895
    private static let metersPerSecondToKnots = 1.9438444924

    let altitudeFeet: Double?
    let groundSpeedKnots: Double?
    let headingDegrees: Double?
    let verticalSpeedFeetPerMinute: Double?
    let connectionHealthLevel: HealthLevel
    let connectionHealthLabel: String

    static let empty = TelemetryCardModel(
        altitudeFeet: nil,
        groundSpeedKnots: nil,
        headingDegrees: nil,
        verticalSpeedFeetPerMinute: nil,
        connectionHealthLevel: .neutral,
        connectionHealthLabel: TelemetryHealth.notConnected.displayLabel
    )

    static func from(context: FlightContext, analysis: FlightAnalysis) -> TelemetryCardModel {
        TelemetryCardModel(
            altitudeFeet: context.altitudeMeters.map { $0 * metersToFeet },
            groundSpeedKnots: context.groundSpeedMetersPerSecond.map { $0 * metersPerSecondToKnots },
            headingDegrees: context.headingDegreesTrue,
            verticalSpeedFeetPerMinute: analysis.estimatedVerticalSpeedFeetPerMinute,
            connectionHealthLevel: analysis.telemetryHealth.healthLevel,
            connectionHealthLabel: analysis.telemetryHealth.displayLabel
        )
    }
}
