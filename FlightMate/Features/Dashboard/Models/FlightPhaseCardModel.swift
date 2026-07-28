//
//  FlightPhaseCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for FlightPhaseCard, derived
//  entirely from FlightAnalysis. FlightPhaseCard never touches
//  FlightAnalysis directly -- only this model.
//

import Foundation

/// Everything `FlightPhaseCard` needs to render, and nothing else.
struct FlightPhaseCardModel: Equatable {
    let phaseDisplayName: String
    let phaseSystemImage: String
    /// "Airborne"/"On Ground"/"Unknown" -- derived solely from
    /// `FlightPhase.isAirborne`, per this card's "use existing
    /// FlightAnalysis only" constraint.
    let flightStatusLabel: String
    let confidenceLevel: AnalysisConfidence.Level
    /// Up to the first 3 reasons behind the current phase, for a concise
    /// explanation -- see the milestone's "Maintaining cruise altitude.
    /// Stable speed. No turn detected." example.
    let phaseReasons: [String]

    static let idle = FlightPhaseCardModel(
        phaseDisplayName: FlightPhase.unknown.displayName,
        phaseSystemImage: FlightPhase.unknown.systemImage,
        flightStatusLabel: "Unknown",
        confidenceLevel: .low,
        phaseReasons: []
    )

    static func from(_ analysis: FlightAnalysis) -> FlightPhaseCardModel {
        let phase = analysis.flightPhase
        let flightStatusLabel: String
        if phase == .unknown {
            flightStatusLabel = "Unknown"
        } else {
            flightStatusLabel = phase.isAirborne ? "Airborne" : "On Ground"
        }

        return FlightPhaseCardModel(
            phaseDisplayName: phase.displayName,
            phaseSystemImage: phase.systemImage,
            flightStatusLabel: flightStatusLabel,
            confidenceLevel: analysis.confidence.level,
            phaseReasons: Array(analysis.phaseReasons.prefix(3))
        )
    }
}
