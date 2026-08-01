//
//  ProcedureVerification.swift
//  FlightMate
//
//  How the user (or future telemetry) confirms a step.
//

import Foundation

/// Step completion check: either the user taps it done, or it can be
/// auto-verified against a telemetry-observable `condition` (ground/air,
/// altitude, speed, or flight phase). `condition` is optional even when
/// `mode == .automatic` so content can be authored incrementally --
/// an automatic step with no condition simply never auto-completes and
/// falls back to manual tap.
struct ProcedureVerification: Codable, Sendable, Hashable {
    enum Mode: String, Codable, Sendable, Hashable {
        case manual
        case automatic
    }

    let mode: Mode
    let condition: ProcedureAutomaticCondition?

    init(mode: Mode, condition: ProcedureAutomaticCondition? = nil) {
        self.mode = mode
        self.condition = condition
    }
}
