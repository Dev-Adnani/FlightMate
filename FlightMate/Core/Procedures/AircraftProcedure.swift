//
//  AircraftProcedure.swift
//  FlightMate
//
//  Full guided procedure document (sections + inline steps).
//

import Foundation

/// One complete guided procedure for an aircraft (e.g. cold & dark).
struct AircraftProcedure: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let aircraft: String
    let version: Int
    let estimatedMinutes: Int
    let difficulty: ProcedureDifficulty
    let fidelity: ProcedureFidelity
    let disclaimer: String
    let sources: [ProcedureSource]
    let sections: [ProcedureSection]

    /// Sections sorted by `order`.
    var orderedSections: [ProcedureSection] {
        sections.sorted { $0.order < $1.order }
    }

    /// Flattened steps in section then step order.
    var allStepsInOrder: [ProcedureStep] {
        orderedSections.flatMap(\.orderedSteps)
    }

    var totalStepCount: Int { allStepsInOrder.count }
}
