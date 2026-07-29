//
//  ProcedureLocation.swift
//  FlightMate
//
//  Where in the cockpit a guided step applies.
//

import Foundation

/// Panel / section / hint describing where to find a control.
struct ProcedureLocation: Codable, Sendable, Hashable {
    let panel: String
    let section: String
    let hint: String
}
