//
//  ReferenceDataLoader.swift
//  FlightMate
//
//  Loads bundled JSON reference data (airports, aircraft) shipped inside
//  the app. This is a cross-cutting, non-domain-specific loading concern —
//  domain-specific lookup logic lives in AirportService / AircraftService.
//

import Foundation
import OSLog

/// Errors that can occur while loading bundled reference data.
enum ReferenceDataError: Error, LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(resource: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Reference data resource '\(name)' was not found in the app bundle."
        case .decodingFailed(let name, let underlying):
            return "Failed to decode reference data resource '\(name)': \(underlying.localizedDescription)"
        }
    }
}

/// Envelope matching the top-level shape of a GeoJSON `FeatureCollection`.
/// `Airport` knows how to decode itself from a single `Feature`, so this
/// envelope only needs to unwrap the `features` array.
private struct AirportFeatureCollection: Decodable {
    let features: [Airport]
}

/// Abstraction over loading bundled reference data, so `AirportService` and
/// `AircraftService` can be unit tested without touching the real bundle.
protocol ReferenceDataLoading {
    func loadAirports() throws -> [Airport]
    func loadAircraft() throws -> [Aircraft]
    func loadAircraftLiveries() throws -> [AircraftLiveryGroup]
}

/// Loads reference data JSON files from `Resources/Airports` and
/// `Resources/Aircraft` inside the app bundle.
final class ReferenceDataLoader: ReferenceDataLoading {
    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    func loadAirports() throws -> [Airport] {
        try decodeResource(AirportFeatureCollection.self, named: "airports", withExtension: "geojson").features
    }

    func loadAircraft() throws -> [Aircraft] {
        // Sourced from aircraft-liveries.json (the richer, canonical file —
        // see fboes/aerofly-data's own index.js). Aircraft doesn't declare a
        // `liveries` key, so it decodes cleanly while ignoring that data;
        // liveries are decoded separately via `loadAircraftLiveries()`.
        try decodeResource([Aircraft].self, named: "aircraft-liveries", withExtension: "json")
    }

    func loadAircraftLiveries() throws -> [AircraftLiveryGroup] {
        try decodeResource([AircraftLiveryGroup].self, named: "aircraft-liveries", withExtension: "json")
    }

    /// Looks up `name.<ext>` anywhere in the bundle (Xcode's file-system
    /// synchronized groups flatten resource subdirectories at build time,
    /// so no subdirectory needs to be specified here).
    private func decodeResource<T: Decodable>(_ type: T.Type, named name: String, withExtension ext: String) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            AppLogger.referenceData.error("Missing bundled resource: \(name, privacy: .public).\(ext, privacy: .public)")
            throw ReferenceDataError.resourceNotFound("\(name).\(ext)")
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLogger.referenceData.error("Failed to decode \(name, privacy: .public).\(ext, privacy: .public): \(String(describing: error), privacy: .public)")
            throw ReferenceDataError.decodingFailed(resource: "\(name).\(ext)", underlying: error)
        }
    }
}
