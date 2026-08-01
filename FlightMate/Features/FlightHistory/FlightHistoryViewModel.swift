//
//  FlightHistoryViewModel.swift
//  FlightMate
//
//  Product UI state for Flight History. Engine mirrors are applied on the
//  next main-queue turn so List selection bindings never nest publishes
//  inside a SwiftUI view update.
//

import Combine
import Foundation

@MainActor
final class FlightHistoryViewModel: ObservableObject {
    @Published private(set) var currentHistory: FlightHistory?
    @Published private(set) var earlierFlights: [FlightHistoryListItem] = []
    @Published var selectedHistoryID: UUID?

    let flightHistoryEngine: FlightHistoryEngine
    private let flightHistoryPersistenceService: FlightHistoryPersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(flightHistoryEngine: FlightHistoryEngine, flightHistoryPersistenceService: FlightHistoryPersistenceService) {
        self.flightHistoryEngine = flightHistoryEngine
        self.flightHistoryPersistenceService = flightHistoryPersistenceService

        Publishers.CombineLatest(
            flightHistoryEngine.$currentHistory,
            flightHistoryEngine.$completedHistories
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] current, completed in
            guard let self else { return }
            DispatchQueue.main.async {
                self.apply(current: current, completed: completed)
            }
        }
        .store(in: &cancellables)
    }

    var selectedHistory: FlightHistoryListItem? {
        if let currentHistory, currentHistory.id == selectedHistoryID {
            return .live(currentHistory)
        }
        return earlierFlights.first { $0.id == selectedHistoryID }
    }

    /// Merges this session's in-memory completed histories (rich: full
    /// event timeline) with persisted records from previous sessions,
    /// newest first. A history already represented in `completed` is
    /// never duplicated as a `.persisted` row, even though
    /// `FlightHistoryPersistenceService` will have already written it to
    /// disk by the time this runs -- `.live` is always preferred since it
    /// carries the full timeline the detail pane can show.
    private func apply(current: FlightHistory?, completed: [FlightHistory]) {
        currentHistory = current

        let liveIDs = Set(completed.map(\.id))
        let persistedOnly = flightHistoryPersistenceService.fetchAll()
            .filter { !liveIDs.contains($0.id) }
            .map(FlightHistoryListItem.persisted)

        earlierFlights = (completed.reversed().map(FlightHistoryListItem.live) + persistedOnly)
            .sorted { $0.startTime > $1.startTime }

        if selectedHistoryID == nil {
            selectedHistoryID = current?.id ?? earlierFlights.first?.id
        }
    }
}
