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
final class PersistenceService {
    static let shared = PersistenceService()

    private init() {}
}
