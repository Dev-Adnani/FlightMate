//
//  PersistenceService.swift
//  FlightMate
//
//  Cross-cutting, non-domain-specific application services (e.g. persistence
//  coordination) live here. Domain services (Telemetry, Airport, Aircraft, AI)
//  live in their own Core folders.
//

import Foundation

/// Placeholder for app-wide persistence coordination on top of SwiftData.
/// Implementation to be added.
///
/// Instances are created and injected by the caller (e.g. the app entry
/// point) rather than accessed through a shared singleton, per project
/// coding rules — this keeps the service mockable in tests.
final class PersistenceService {
    init() {}
}
