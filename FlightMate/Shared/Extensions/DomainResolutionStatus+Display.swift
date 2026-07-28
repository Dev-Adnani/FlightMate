//
//  DomainResolutionStatus+Display.swift
//  FlightMate
//
//  Presentation-only mapping from DomainResolutionStatus
//  (Core/DomainResolution) to a HealthLevel + human-readable label. Purely
//  additive -- never modifies DomainResolutionStatus itself.
//

import Foundation

extension DomainResolutionStatus {
    /// The shared status color/level this resolution status maps to.
    var healthLevel: HealthLevel {
        switch self {
        case .resolved: return .healthy
        case .partial: return .warning
        case .unresolved: return .critical
        }
    }

    /// Short, user-facing label.
    var displayLabel: String {
        switch self {
        case .resolved: return "Resolved"
        case .partial: return "Partially Resolved"
        case .unresolved: return "Unresolved"
        }
    }

    /// Combines several statuses into the single worst one -- `unresolved`
    /// beats `partial` beats `resolved`. Used to summarize e.g. aircraft +
    /// departure + destination resolution into one overall indicator.
    /// Returns `nil` if `statuses` is empty (nothing to summarize yet).
    static func worst(of statuses: [DomainResolutionStatus]) -> DomainResolutionStatus? {
        if statuses.contains(.unresolved) { return .unresolved }
        if statuses.contains(.partial) { return .partial }
        return statuses.first
    }
}
