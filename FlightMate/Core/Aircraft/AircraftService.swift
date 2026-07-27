//
//  AircraftService.swift
//  FlightMate
//
//  Resolves the currently active aircraft and its reference data.
//

import Combine
import Foundation

/// Aircraft lookup capabilities used to enrich the AI's flight context.
protocol AircraftProviding {
    /// Looks up an aircraft by its Aerofly identifier (e.g. "a320_neo").
    func aircraft(id: String) -> Aircraft?

    /// All aircraft known to the bundled reference data.
    func allAircraft() -> [Aircraft]

    /// Liveries available for a given aircraft, in bundled order. Returns an
    /// empty array if the aircraft is unknown or has no liveries.
    func liveries(for aircraftId: String) -> [AircraftLivery]

    /// Finds every livery, across all aircraft, whose airline ICAO code
    /// matches `icaoCode` (case-insensitive), paired with the aircraft it
    /// belongs to.
    func liveries(icaoCode: String) -> [AircraftLiveryMatch]
}

/// Default `AircraftProviding` implementation backed by bundled reference
/// data loaded once at initialization time.
final class AircraftService: AircraftProviding, ObservableObject {
    private let aircraftList: [Aircraft]
    private let aircraftByID: [String: Aircraft]
    private let liveriesByAircraftID: [String: [AircraftLivery]]

    /// - Parameter loader: Source of bundled reference data. Injected so
    ///   this service can be unit tested with fake/fixture data.
    init(loader: ReferenceDataLoading = ReferenceDataLoader()) {
        let aircraft = (try? loader.loadAircraft()) ?? []
        self.aircraftList = aircraft
        self.aircraftByID = Dictionary(
            aircraft.map { ($0.aeroflyCode, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let liveryGroups = (try? loader.loadAircraftLiveries()) ?? []
        self.liveriesByAircraftID = Dictionary(
            liveryGroups.map { ($0.aeroflyCode, $0.liveries) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func aircraft(id: String) -> Aircraft? {
        aircraftByID[id]
    }

    func allAircraft() -> [Aircraft] {
        aircraftList
    }

    func liveries(for aircraftId: String) -> [AircraftLivery] {
        liveriesByAircraftID[aircraftId] ?? []
    }

    func liveries(icaoCode: String) -> [AircraftLiveryMatch] {
        let normalized = icaoCode.uppercased()
        return liveriesByAircraftID.flatMap { aircraftId, liveries in
            liveries
                .filter { $0.icaoCode?.uppercased() == normalized }
                .map { AircraftLiveryMatch(aircraftId: aircraftId, livery: $0) }
        }
    }
}
