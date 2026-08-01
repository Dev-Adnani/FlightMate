//
//  ProcedureAutomaticCondition.swift
//  FlightMate
//
//  The closed set of telemetry-observable conditions a procedure step can
//  ask to be auto-verified against -- see ProcedureConditionEvaluator for
//  how each kind is actually checked, and ProcedureVerification's doc
//  comment for why this deliberately does *not* cover switch/panel state
//  (Aerofly's UDP feed and session file expose no systems telemetry at
//  all, only position/attitude/speed -- see PROJECT_CONTEXT.md and the
//  DLL-feasibility research this schema followed from).
//

import Foundation

struct ProcedureAutomaticCondition: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable, Hashable {
        case onGround
        case minAltitudeFeet
        case maxAltitudeFeet
        case minGroundSpeedKnots
        case maxGroundSpeedKnots
        case flightPhase
    }

    let kind: Kind

    /// Threshold for `.minAltitudeFeet`/`.maxAltitudeFeet`/
    /// `.minGroundSpeedKnots`/`.maxGroundSpeedKnots`. Unused for
    /// `.onGround`/`.flightPhase` -- omit in content JSON for those kinds.
    let value: Double?

    /// Target phase name for `.flightPhase`, matching `FlightPhase`'s
    /// case names exactly (e.g. `"cruise"`, `"descent"`). Unused for
    /// every other kind.
    let phase: String?
}
