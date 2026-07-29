//
//  ProcedureSection.swift
//  FlightMate
//
//  Ordered group of steps within a procedure.
//

import Foundation

struct ProcedureSection: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let optional: Bool?
    let steps: [ProcedureStep]

    var isOptional: Bool { optional ?? false }

    /// Steps sorted by `order`.
    var orderedSteps: [ProcedureStep] {
        steps.sorted { $0.order < $1.order }
    }
}
