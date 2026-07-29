//
//  ProcedureDifficulty.swift
//  FlightMate
//
//  Difficulty tags for procedures and steps.
//

import Foundation

enum ProcedureDifficulty: String, Codable, Sendable, Hashable {
    case beginner
    case intermediate
    case advanced
}
