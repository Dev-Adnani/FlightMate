//
//  AircraftCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for AircraftCard, derived entirely
//  from FlightAnalysis.resolvedAircraft. AircraftCard never touches
//  FlightAnalysis or ResolvedAircraft directly -- only this model.
//

import Foundation

/// Everything `AircraftCard` needs to render, and nothing else.
struct AircraftCardModel: Equatable {
    let aircraftName: String
    let categoryDisplayName: String?
    let liveryName: String?
    let isResolved: Bool
    let hasSelection: Bool

    /// A single, consistent placeholder icon -- see the milestone's
    /// "Aircraft Icon (placeholder if needed)" guidance. Deliberately not
    /// varied per `AircraftCategory` to avoid depending on SF Symbols that
    /// may not exist for every category.
    static let iconSystemImage = "airplane.circle.fill"

    /// The state before any aircraft has ever been selected in the
    /// simulator.
    static let noSelection = AircraftCardModel(
        aircraftName: "No Aircraft Loaded",
        categoryDisplayName: nil,
        liveryName: nil,
        isResolved: false,
        hasSelection: false
    )

    static func from(_ analysis: FlightAnalysis) -> AircraftCardModel {
        guard let resolved = analysis.resolvedAircraft else { return .noSelection }

        return AircraftCardModel(
            aircraftName: resolved.aircraft?.nameFull ?? resolved.aircraftCode,
            categoryDisplayName: resolved.category?.displayName,
            liveryName: resolved.livery?.name ?? (resolved.liveryCode.isEmpty ? nil : resolved.liveryCode),
            isResolved: resolved.status == .resolved,
            hasSelection: true
        )
    }
}
