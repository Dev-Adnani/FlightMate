//
//  ProcedureSource.swift
//  FlightMate
//
//  Attribution for procedure content origins.
//

import Foundation

/// One documented source used when authoring a procedure.
struct ProcedureSource: Codable, Sendable, Hashable {
    let title: String
    let url: String?
}
