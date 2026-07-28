//
//  HealthLevel.swift
//  FlightMate
//
//  A generic, three-plus-one-state indicator for any "is this healthy?"
//  signal shown in the UI (connection health, session status, resolution
//  status, event severity, etc). Lives in Shared, not any one Feature, so
//  every card/screen that needs a colored status indicator maps its own
//  domain enum onto this one shared vocabulary instead of inventing its
//  own color scheme.
//

import Foundation

/// A presentation-only status level, independent of any specific domain
/// concept. Concrete domain types (e.g. `TelemetryHealth`,
/// `AeroflySessionState`, `DomainResolutionStatus`) map onto this via small
/// `+Display` extensions in `Shared/Extensions` -- this type itself knows
/// nothing about telemetry, sessions, or aviation.
enum HealthLevel: Equatable {
    /// Everything is working as expected -- rendered green.
    case healthy
    /// Degraded, but not broken -- rendered yellow.
    case warning
    /// Broken or disconnected -- rendered red.
    case critical
    /// Neutral, non-actionable information -- rendered blue.
    case informational
    /// No signal yet to judge (e.g. nothing has loaded at all) -- rendered
    /// with the system's secondary label color.
    case neutral
}
