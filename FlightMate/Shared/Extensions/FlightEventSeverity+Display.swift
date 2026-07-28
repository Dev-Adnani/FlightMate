//
//  FlightEventSeverity+Display.swift
//  FlightMate
//
//  Presentation-only mapping from FlightEventSeverity (Core/FlightEvents)
//  to a HealthLevel. Purely additive -- never modifies FlightEventSeverity
//  itself. Every event is `.info` today, but the mapping is written to
//  support `.warning`/`.critical` the moment a future milestone emits them
//  -- see FlightEventSeverity's own doc comment.
//

import Foundation

extension FlightEventSeverity {
    /// The shared status color/level this severity maps to.
    var healthLevel: HealthLevel {
        switch self {
        case .info: return .informational
        case .warning: return .warning
        case .critical: return .critical
        }
    }
}
