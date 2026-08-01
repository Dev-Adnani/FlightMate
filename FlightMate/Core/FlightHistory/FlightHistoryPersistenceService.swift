//
//  FlightHistoryPersistenceService.swift
//  FlightMate
//
//  Bridges the in-memory FlightHistoryEngine to permanent storage: watches
//  completedHistories for newly finalized flights and writes each one,
//  once, as a PersistedFlightRecord. Read access for the logbook UI is
//  also exposed here, so FlightHistoryViewModel has a single collaborator
//  for both.
//

import Combine
import Foundation
import SwiftData

/// Persists completed flights and reads them back for the Flight History
/// logbook.
///
/// ## Dependency injection
/// Not a singleton. `FlightHistoryEngine` (source of newly finalized
/// flights) and `PersistenceService` (owner of the shared `ModelContainer`)
/// are both required, constructor-injected dependencies -- this type
/// creates neither.
///
/// ## What gets persisted
/// Every history in `FlightHistoryEngine.completedHistories` that
/// satisfies `hasStartedFlight` (a real takeoff was recorded) and hasn't
/// already been written this process's lifetime -- tracked by
/// `persistedIDs`, since `completedHistories` publishes the same array
/// again on every subsequent flight completion, not just newly appended
/// entries. A history that never left the ground (aircraft loaded, then
/// immediately swapped or reset) is not a meaningful logbook entry and is
/// silently skipped, matching `FlightHistoryRow`'s own "Preflight" display
/// rule.
@MainActor
final class FlightHistoryPersistenceService: ObservableObject {
    private let modelContext: ModelContext
    private var persistedIDs: Set<UUID> = []
    private var cancellable: AnyCancellable?

    /// - Parameters:
    ///   - flightHistoryEngine: Source of newly finalized flights.
    ///   - persistenceService: Owner of the shared `ModelContainer` this
    ///     service reads/writes through.
    init(flightHistoryEngine: FlightHistoryEngine, persistenceService: PersistenceService) {
        self.modelContext = persistenceService.mainContext
        self.persistedIDs = Set(Self.fetchAllIDs(in: modelContext))

        cancellable = flightHistoryEngine.$completedHistories
            .sink { [weak self] histories in
                self?.persist(newlyCompleted: histories)
            }
    }

    /// All persisted flights, newest first -- for the Flight History
    /// logbook to merge alongside this session's in-memory histories.
    func fetchAll() -> [PersistedFlightRecord] {
        let descriptor = FetchDescriptor<PersistedFlightRecord>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func persist(newlyCompleted histories: [FlightHistory]) {
        var didInsert = false
        for history in histories where history.hasStartedFlight && !persistedIDs.contains(history.id) {
            modelContext.insert(PersistedFlightRecord(summarizing: history))
            persistedIDs.insert(history.id)
            didInsert = true
        }

        guard didInsert else { return }
        try? modelContext.save()
    }

    private static func fetchAllIDs(in context: ModelContext) -> [UUID] {
        let descriptor = FetchDescriptor<PersistedFlightRecord>()
        return ((try? context.fetch(descriptor)) ?? []).map(\.id)
    }
}
