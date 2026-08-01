//
//  ProcedureConditionEvaluator.swift
//  FlightMate
//
//  Pure function that checks a single ProcedureAutomaticCondition against
//  the current telemetry snapshot. Kept stateless and side-effect free so
//  it's trivial to unit test in isolation from ProceduresViewModel.
//

import Foundation

enum ProcedureConditionEvaluator {
    /// - Returns: `true` if `condition` currently holds given `context`
    ///   (raw telemetry) and `analysis` (derived flight phase). `false`
    ///   whenever the telemetry needed to evaluate the condition hasn't
    ///   arrived yet, so steps never auto-complete on missing data.
    static func isSatisfied(
        _ condition: ProcedureAutomaticCondition,
        context: FlightContext,
        analysis: FlightAnalysis
    ) -> Bool {
        switch condition.kind {
        case .onGround:
            return !analysis.flightPhase.isAirborne

        case .minAltitudeFeet:
            guard let threshold = condition.value, let altitudeMeters = context.altitudeMeters else { return false }
            return UnitConversion.feet(fromMeters: altitudeMeters) >= threshold

        case .maxAltitudeFeet:
            guard let threshold = condition.value, let altitudeMeters = context.altitudeMeters else { return false }
            return UnitConversion.feet(fromMeters: altitudeMeters) <= threshold

        case .minGroundSpeedKnots:
            guard let threshold = condition.value, let speedMetersPerSecond = context.groundSpeedMetersPerSecond else { return false }
            return UnitConversion.knots(fromMetersPerSecond: speedMetersPerSecond) >= threshold

        case .maxGroundSpeedKnots:
            guard let threshold = condition.value, let speedMetersPerSecond = context.groundSpeedMetersPerSecond else { return false }
            return UnitConversion.knots(fromMetersPerSecond: speedMetersPerSecond) <= threshold

        case .flightPhase:
            guard let phaseName = condition.phase else { return false }
            return FlightPhase(procedureContentName: phaseName) == analysis.flightPhase
        }
    }
}
