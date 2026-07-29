//
//  ProcedureAircraft.swift
//  FlightMate
//
//  Knowledge-base aircraft entry that lists available procedures.
//

import Foundation

/// Aircraft metadata for the guided-procedures knowledge base.
///
/// Distinct from reference `Aircraft` (performance / liveries). Identity
/// still uses the Aerofly code (`id` == `a320_neo`).
struct ProcedureAircraft: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let manufacturer: String
    let family: String
    let category: String
    let fidelity: ProcedureFidelity
    let supportedProcedures: [String]
    /// Optional parent aircraft id for Tier-B family reuse.
    let inheritsProceduresFrom: String?
}
