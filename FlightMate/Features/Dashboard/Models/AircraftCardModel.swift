//
//  AircraftCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for AircraftCard, derived from
//  FlightAnalysis.resolvedAircraft plus a resolved AircraftAsset from
//  AircraftAssetManager. AircraftCard never touches FlightAnalysis,
//  ResolvedAircraft, or the asset manager directly -- only this model.
//

import Foundation

/// Everything `AircraftCard` needs to render, and nothing else.
struct AircraftCardModel: Equatable {
    let aircraftName: String
    let categoryDisplayName: String?
    let liveryName: String?
    let isResolved: Bool
    let hasSelection: Bool
    /// Preview resolved by `AircraftAssetManager` -- never a hardcoded
    /// image name. Always present (the manager's SF Symbol fallback is
    /// total), including for `.noSelection`.
    let asset: AircraftAsset

    /// The state before any aircraft has ever been selected in the
    /// simulator.
    static let noSelection = AircraftCardModel(
        aircraftName: "No Aircraft Loaded",
        categoryDisplayName: nil,
        liveryName: nil,
        isResolved: false,
        hasSelection: false,
        asset: AircraftAsset(
            content: .systemSymbol(name: SystemSymbolAssetProvider.fallbackSystemImage),
            source: .systemSymbol,
            cacheKey: "no-selection"
        )
    )

    static func from(_ analysis: FlightAnalysis, assetManager: AircraftAssetManaging) -> AircraftCardModel {
        guard let resolved = analysis.resolvedAircraft else { return .noSelection }

        return AircraftCardModel(
            aircraftName: resolved.aircraft?.nameFull ?? resolved.aircraftCode,
            categoryDisplayName: resolved.category?.displayName,
            liveryName: resolved.livery?.name ?? (resolved.liveryCode.isEmpty ? nil : resolved.liveryCode),
            isResolved: resolved.status == .resolved,
            hasSelection: true,
            asset: assetManager.resolve(aircraft: resolved)
        )
    }
}
