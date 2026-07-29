//
//  AirportViewModel.swift
//  FlightMate
//
//  Search bundled airports; surface live departure / destination / nearest
//  from FlightAnalysisEngine. Engine-driven `@Published` writes are deferred
//  off the current SwiftUI view-update turn.
//

import Combine
import Foundation

@MainActor
final class AirportViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var results: [Airport] = []
    @Published var selectedICAO: String?
    @Published private(set) var departureICAO: String?
    @Published private(set) var destinationICAO: String?
    @Published private(set) var nearestICAO: String?
    @Published private(set) var suggestedAirports: [Airport] = []

    private let airportProvider: AirportProviding
    private var cancellables = Set<AnyCancellable>()

    init(
        airportProvider: AirportProviding,
        flightAnalysisEngine: FlightAnalysisEngine
    ) {
        self.airportProvider = airportProvider

        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.runSearch(query)
            }
            .store(in: &cancellables)

        flightAnalysisEngine.$analysis
            .receive(on: DispatchQueue.main)
            .sink { [weak self] analysis in
                guard let self else { return }
                // Defer past any in-flight SwiftUI/MapKit layout pass.
                DispatchQueue.main.async {
                    self.applyLiveContext(analysis)
                }
            }
            .store(in: &cancellables)
    }

    var selectedAirport: Airport? {
        guard let selectedICAO else { return nil }
        return airportProvider.airport(icao: selectedICAO)
    }

    private func runSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextResults: [Airport]
        if trimmed.isEmpty {
            nextResults = []
        } else {
            nextResults = airportProvider.searchAirports(query: trimmed, limit: 50)
        }

        results = nextResults
        if selectedICAO == nil, let first = nextResults.first {
            // Selection write after results — already off the search-binding
            // turn thanks to debounce; keep it explicit for clarity.
            selectedICAO = first.icaoCode
        }
    }

    private func applyLiveContext(_ analysis: FlightAnalysis) {
        let departure = analysis.resolvedDeparture?.icaoCode
        let destination = analysis.resolvedDestination?.icaoCode
        let nearest = analysis.nearestAirport?.icaoCode

        departureICAO = departure
        destinationICAO = destination
        nearestICAO = nearest

        var suggestions: [Airport] = []
        for code in [departure, destination, nearest].compactMap({ $0 }) {
            if let airport = airportProvider.airport(icao: code),
               !suggestions.contains(where: { $0.icaoCode == airport.icaoCode }) {
                suggestions.append(airport)
            }
        }
        suggestedAirports = suggestions

        if selectedICAO == nil, let first = suggestions.first {
            selectedICAO = first.icaoCode
        }
    }

    func roleLabel(for icao: String) -> String? {
        if icao == departureICAO { return "Departure" }
        if icao == destinationICAO { return "Destination" }
        if icao == nearestICAO { return "Nearest" }
        return nil
    }
}
