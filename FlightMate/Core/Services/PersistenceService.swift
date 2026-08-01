//
//  PersistenceService.swift
//  FlightMate
//
//  Cross-cutting, non-domain-specific application services (e.g. persistence
//  coordination) live here. Domain services (Telemetry, Airport, Aircraft, AI)
//  live in their own Core folders.
//

import Foundation
import SwiftData

/// Owns the app's single SwiftData `ModelContainer`/`ModelContext` pair.
///
/// Every persisted model FlightMate defines (today: just
/// `PersistedFlightRecord`) is registered in `schema` here -- domain
/// services (e.g. `FlightHistoryPersistenceService`) read/write through
/// the `ModelContext` this type exposes, they never construct their own
/// container. Constructed once by `AppServices` and injected everywhere
/// else, per project coding rules -- never a singleton.
final class PersistenceService {
    let modelContainer: ModelContainer

    /// The single main-actor-bound context every service reads/writes
    /// through. SwiftData's `ModelContext` is not `Sendable`; sharing one
    /// context (rather than creating a new one per service) keeps every
    /// write visible to every reader without an explicit save/refetch
    /// round trip.
    @MainActor
    var mainContext: ModelContext { modelContainer.mainContext }

    /// - Parameter isStoredInMemoryOnly: `true` for tests/previews that
    ///   want a throwaway store; `false` (the default) persists to disk
    ///   across app launches.
    init(isStoredInMemoryOnly: Bool = false) {
        let schema = Schema([PersistedFlightRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
