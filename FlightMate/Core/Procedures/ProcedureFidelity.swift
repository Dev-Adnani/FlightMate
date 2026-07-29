//
//  ProcedureFidelity.swift
//  FlightMate
//
//  Content quality tier for guided procedures.
//

import Foundation

/// How thoroughly a procedure (or aircraft procedure set) was validated.
enum ProcedureFidelity: String, Codable, Sendable, Hashable {
    /// Curated from official Aerofly docs and/or verified in-sim.
    case aeroflyVerified = "aerofly_verified"
    /// Inherited from a sibling aircraft with small overrides.
    case familyDerived = "family_derived"
    /// Authoring in progress — not the primary teaching path yet.
    case draft
}
