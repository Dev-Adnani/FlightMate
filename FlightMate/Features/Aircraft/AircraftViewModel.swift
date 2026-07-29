//
//  AircraftViewModel.swift
//  FlightMate
//
//  Browse / search bundled aircraft; highlight the live selection from
//  FlightAnalysisEngine. Derived list/detail state is computed so binding
//  updates never cascade into nested `@Published` writes during a view pass.
//

import Combine
import Foundation

@MainActor
final class AircraftViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedAircraftID: String?
    @Published private(set) var currentAircraftCode: String?

    private let aircraftProvider: AircraftProviding
    private let aircraftAssetManager: AircraftAssetManaging
    private let allAircraft: [Aircraft]
    /// Sorted-catalog default used when the browser first opens; live
    /// follow only auto-selects while still on this default (or when the
    /// live code itself changes).
    private let initialCatalogSelectionID: String?
    private var lastFollowedLiveCode: String?
    private var cancellables = Set<AnyCancellable>()

    init(
        aircraftProvider: AircraftProviding,
        flightAnalysisEngine: FlightAnalysisEngine,
        aircraftAssetManager: AircraftAssetManaging
    ) {
        self.aircraftProvider = aircraftProvider
        self.aircraftAssetManager = aircraftAssetManager
        self.allAircraft = aircraftProvider.allAircraft().sorted {
            $0.nameFull.localizedCaseInsensitiveCompare($1.nameFull) == .orderedAscending
        }
        let initialID = allAircraft.first?.id
        self.initialCatalogSelectionID = initialID
        self.selectedAircraftID = initialID

        // Async hop so engine replay never assigns during `@StateObject` init
        // / a SwiftUI view update.
        flightAnalysisEngine.$analysis
            .map { $0.resolvedAircraft?.aircraftCode }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] code in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.applyLiveAircraftCode(code)
                }
            }
            .store(in: &cancellables)
    }

    /// Updates the Current badge and, when appropriate, the detail selection
    /// so the browser follows the simulator instead of staying on a
    /// previously tapped plane (e.g. Cessna).
    private func applyLiveAircraftCode(_ code: String?) {
        currentAircraftCode = code

        guard let code,
              allAircraft.contains(where: { $0.aeroflyCode == code }) else {
            return
        }

        let liveChanged = lastFollowedLiveCode != code
        let stillOnInitialDefault =
            selectedAircraftID == initialCatalogSelectionID && lastFollowedLiveCode == nil

        if liveChanged || stillOnInitialDefault {
            selectedAircraftID = code
            lastFollowedLiveCode = code
        }
    }

    var filteredAircraft: [Aircraft] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allAircraft }
        return allAircraft.filter { aircraft in
            aircraft.name.localizedCaseInsensitiveContains(trimmed)
                || aircraft.nameFull.localizedCaseInsensitiveContains(trimmed)
                || aircraft.aeroflyCode.localizedCaseInsensitiveContains(trimmed)
                || aircraft.icaoCode.localizedCaseInsensitiveContains(trimmed)
                || aircraft.category.displayName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var selectedAircraft: Aircraft? {
        guard let selectedAircraftID else { return nil }
        return allAircraft.first { $0.id == selectedAircraftID }
    }

    var selectedLiveries: [AircraftLivery] {
        guard let aircraft = selectedAircraft else { return [] }
        return aircraftProvider.liveries(for: aircraft.aeroflyCode)
    }

    var selectedAsset: AircraftAsset? {
        guard let aircraft = selectedAircraft else { return nil }
        return aircraftAssetManager.resolve(
            AircraftAssetRequest(
                aircraftCode: aircraft.aeroflyCode,
                category: aircraft.category,
                preferredSize: .regular
            )
        )
    }
}
