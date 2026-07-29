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
    @Published private(set) var earlierFlights: [FlightHistory] = []
    @Published var selectedHistoryID: UUID?

    let flightHistoryEngine: FlightHistoryEngine
    private var cancellables = Set<AnyCancellable>()

    init(flightHistoryEngine: FlightHistoryEngine) {
        self.flightHistoryEngine = flightHistoryEngine

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

    var selectedHistory: FlightHistory? {
        if let currentHistory, currentHistory.id == selectedHistoryID {
            return currentHistory
        }
        return earlierFlights.first { $0.id == selectedHistoryID }
    }

    private func apply(current: FlightHistory?, completed: [FlightHistory]) {
        currentHistory = current
        earlierFlights = Array(completed.reversed())
        if selectedHistoryID == nil {
            selectedHistoryID = current?.id ?? earlierFlights.first?.id
        }
    }
}
