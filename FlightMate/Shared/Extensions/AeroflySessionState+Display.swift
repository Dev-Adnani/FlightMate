//
//  AeroflySessionState+Display.swift
//  FlightMate
//
//  Presentation-only mapping from AeroflySessionState (Core/AeroflySession)
//  to a HealthLevel + human-readable label. Purely additive -- never
//  modifies AeroflySessionState itself.
//

import Foundation

extension AeroflySessionState {
    /// The shared status color/level this session state maps to.
    var healthLevel: HealthLevel {
        switch self {
        case .notStarted: return .neutral
        case .userDirectoryNotFound, .parseFailed: return .critical
        case .fileNotFound: return .warning
        case .loaded: return .healthy
        }
    }

    /// Short, user-facing label -- no file paths or raw error text.
    var displayLabel: String {
        switch self {
        case .notStarted: return "Not Started"
        case .userDirectoryNotFound: return "Aerofly Not Found"
        case .fileNotFound: return "Waiting for Aerofly"
        case .loaded: return "Connected"
        case .parseFailed: return "Session Error"
        }
    }
}
