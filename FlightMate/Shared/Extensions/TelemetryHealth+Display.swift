//
//  TelemetryHealth+Display.swift
//  FlightMate
//
//  Presentation-only mapping from TelemetryHealth (Core/FlightAnalysis) to
//  a HealthLevel + human-readable label. Purely additive -- never modifies
//  TelemetryHealth itself.
//

import Foundation

extension TelemetryHealth {
    /// The shared status color/level this telemetry health maps to.
    var healthLevel: HealthLevel {
        switch self {
        case .notConnected: return .critical
        case .acquiring: return .warning
        case .live: return .healthy
        case .stale: return .warning
        }
    }

    /// Short, user-facing label -- no debug jargon.
    var displayLabel: String {
        switch self {
        case .notConnected: return "Not Connected"
        case .acquiring: return "Acquiring Signal"
        case .live: return "Live"
        case .stale: return "Signal Delayed"
        }
    }
}
