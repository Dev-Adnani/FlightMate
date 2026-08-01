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
    /// Flight-phase names (see `FlightPhase.init(procedureContentName:)`)
    /// this section is normally performed during, e.g. `["parked"]` for a
    /// cold & dark section or `["approach", "landing"]` for a landing
    /// checklist. `nil`/empty means "not phase-restricted" -- always
    /// considered relevant, which is also the correct fallback for older
    /// content authored before phase tagging existed.
    let applicablePhases: [String]?
    let steps: [ProcedureStep]

    init(
        id: String,
        title: String,
        order: Int,
        optional: Bool?,
        applicablePhases: [String]? = nil,
        steps: [ProcedureStep]
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.optional = optional
        self.applicablePhases = applicablePhases
        self.steps = steps
    }

    var isOptional: Bool { optional ?? false }

    /// Steps sorted by `order`.
    var orderedSteps: [ProcedureStep] {
        steps.sorted { $0.order < $1.order }
    }

    /// Parsed, valid phases from `applicablePhases`. Unrecognized names
    /// are silently dropped rather than failing the whole section.
    var phases: [FlightPhase] {
        (applicablePhases ?? []).compactMap(FlightPhase.init(procedureContentName:))
    }

    /// Whether this section is normally performed during `phase`. Always
    /// `true` when the section carries no phase tags.
    func isApplicable(to phase: FlightPhase) -> Bool {
        phases.isEmpty || phases.contains(phase)
    }
}
