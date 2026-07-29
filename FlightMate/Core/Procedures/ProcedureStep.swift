//
//  ProcedureStep.swift
//  FlightMate
//
//  One guided action inside a procedure section.
//

import Foundation

/// A single Duolingo-style teaching step.
struct ProcedureStep: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let order: Int
    let title: String
    let instruction: String
    let purpose: String
    let location: ProcedureLocation
    let expectedResult: [String]
    let verification: ProcedureVerification
    let condition: String?
    let caution: String?
    let notes: [String]?
    let estimatedSeconds: Int?
    let difficulty: ProcedureDifficulty?
    let highlight: String?
    let references: [String]?
}
