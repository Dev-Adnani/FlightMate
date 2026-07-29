//
//  KnowledgeDataLoader.swift
//  FlightMate
//
//  Loads bundled guided-procedure JSON from Resources/Knowledge.
//

import Foundation
import OSLog

/// Errors while loading procedure knowledge resources.
enum KnowledgeDataError: Error, LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(resource: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Knowledge resource '\(name)' was not found in the app bundle."
        case .decodingFailed(let name, let underlying):
            return "Failed to decode knowledge resource '\(name)': \(underlying.localizedDescription)"
        }
    }
}

/// Abstraction over bundled procedure knowledge so `ProcedureService` is
/// unit-testable without touching the real bundle.
protocol KnowledgeDataLoading {
    func loadProcedureAircraftIndex() throws -> [String]
    func loadProcedureAircraft(id: String) throws -> ProcedureAircraft
    func loadProcedure(aircraftId: String, procedureId: String) throws -> AircraftProcedure
}

/// Loads Knowledge JSON using unique basenames (Xcode flattens folders).
final class KnowledgeDataLoader: KnowledgeDataLoading {
    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    func loadProcedureAircraftIndex() throws -> [String] {
        try decodeResource([String].self, named: "procedure_aircraft_index")
    }

    func loadProcedureAircraft(id: String) throws -> ProcedureAircraft {
        try decodeResource(ProcedureAircraft.self, named: "\(id).aircraft")
    }

    func loadProcedure(aircraftId: String, procedureId: String) throws -> AircraftProcedure {
        try decodeResource(AircraftProcedure.self, named: "\(aircraftId).\(procedureId)")
    }

    private func decodeResource<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            AppLogger.knowledge.error("Missing knowledge resource: \(name, privacy: .public).json")
            throw KnowledgeDataError.resourceNotFound("\(name).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            AppLogger.knowledge.error(
                "Failed to decode \(name, privacy: .public).json: \(String(describing: error), privacy: .public)"
            )
            throw KnowledgeDataError.decodingFailed(resource: "\(name).json", underlying: error)
        }
    }
}
