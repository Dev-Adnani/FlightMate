//
//  ProcedureService.swift
//  FlightMate
//
//  Lookup API for guided procedures. Loads knowledge once at init.
//

import Foundation

/// Read API for the guided-procedures knowledge base.
protocol ProcedureProviding {
    func allAircraft() -> [ProcedureAircraft]
    func aircraft(id: String) -> ProcedureAircraft?
    func procedures(for aircraftId: String) -> [AircraftProcedure]
    func procedure(aircraftId: String, procedureId: String) -> AircraftProcedure?
}

/// Default `ProcedureProviding` backed by bundled Knowledge JSON.
final class ProcedureService: ProcedureProviding {
    private let aircraftList: [ProcedureAircraft]
    private let aircraftByID: [String: ProcedureAircraft]
    private let proceduresByAircraftID: [String: [AircraftProcedure]]

    /// - Parameter loader: Injected so tests can supply fixtures.
    init(loader: KnowledgeDataLoading = KnowledgeDataLoader()) {
        let ids = (try? loader.loadProcedureAircraftIndex()) ?? []
        var aircraft: [ProcedureAircraft] = []
        var procedures: [String: [AircraftProcedure]] = [:]

        for id in ids {
            guard let meta = try? loader.loadProcedureAircraft(id: id) else { continue }
            aircraft.append(meta)

            var loaded: [AircraftProcedure] = []
            for procedureId in meta.supportedProcedures {
                if let procedure = try? loader.loadProcedure(aircraftId: id, procedureId: procedureId) {
                    loaded.append(procedure)
                }
            }
            procedures[id] = loaded
        }

        aircraftList = aircraft
        aircraftByID = Dictionary(uniqueKeysWithValues: aircraft.map { ($0.id, $0) })
        proceduresByAircraftID = procedures
    }

    func allAircraft() -> [ProcedureAircraft] {
        aircraftList
    }

    func aircraft(id: String) -> ProcedureAircraft? {
        aircraftByID[id]
    }

    func procedures(for aircraftId: String) -> [AircraftProcedure] {
        proceduresByAircraftID[aircraftId] ?? []
    }

    func procedure(aircraftId: String, procedureId: String) -> AircraftProcedure? {
        procedures(for: aircraftId).first { $0.id == procedureId }
    }
}
