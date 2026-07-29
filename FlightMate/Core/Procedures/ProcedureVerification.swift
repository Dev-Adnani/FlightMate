//
//  ProcedureVerification.swift
//  FlightMate
//
//  How the user (or future telemetry) confirms a step.
//

import Foundation

/// Step completion check. Phase 1 is always manual; automatic + telemetry
/// can be added later without breaking the schema.
struct ProcedureVerification: Codable, Sendable, Hashable {
    enum Mode: String, Codable, Sendable, Hashable {
        case manual
        case automatic
    }

    let mode: Mode
}
