//
//  ConnectionStatusCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for ConnectionStatusCard, derived
//  from FlightAnalysis (telemetry health, resolution statuses) and
//  FlightContext (session state -- see TelemetryCardModel for why
//  FlightContext is read here rather than main.mcf/AeroflySessionService
//  directly). ConnectionStatusCard never touches FlightContext or
//  FlightAnalysis directly -- only this model.
//

import Foundation

/// Everything `ConnectionStatusCard` needs to render, and nothing else.
struct ConnectionStatusCardModel: Equatable {
    let telemetryLabel: String
    let telemetryLevel: HealthLevel

    let sessionLabel: String
    let sessionLevel: HealthLevel

    let referenceResolutionLabel: String
    let referenceResolutionLevel: HealthLevel

    /// The worst of the three levels above -- one glance answers "is
    /// everything healthy?" without reading every row.
    let overallLevel: HealthLevel
    let overallLabel: String

    static let empty = ConnectionStatusCardModel(
        telemetryLabel: TelemetryHealth.notConnected.displayLabel,
        telemetryLevel: .neutral,
        sessionLabel: AeroflySessionState.notStarted.displayLabel,
        sessionLevel: .neutral,
        referenceResolutionLabel: "No Data Yet",
        referenceResolutionLevel: .neutral,
        overallLevel: .neutral,
        overallLabel: "Waiting for Data"
    )

    static func from(context: FlightContext, analysis: FlightAnalysis) -> ConnectionStatusCardModel {
        let telemetryLevel = analysis.telemetryHealth.healthLevel
        let sessionLevel = context.aeroflySessionState.healthLevel

        let resolutionStatuses = [
            analysis.resolvedAircraft?.status,
            analysis.resolvedDeparture?.status,
            analysis.resolvedDestination?.status
        ].compactMap { $0 }
        let worstResolution = DomainResolutionStatus.worst(of: resolutionStatuses)
        let referenceResolutionLevel = worstResolution?.healthLevel ?? .neutral
        let referenceResolutionLabel = worstResolution?.displayLabel ?? "No Data Yet"

        let overallLevel = worst(of: [telemetryLevel, sessionLevel, referenceResolutionLevel])

        return ConnectionStatusCardModel(
            telemetryLabel: analysis.telemetryHealth.displayLabel,
            telemetryLevel: telemetryLevel,
            sessionLabel: context.aeroflySessionState.displayLabel,
            sessionLevel: sessionLevel,
            referenceResolutionLabel: referenceResolutionLabel,
            referenceResolutionLevel: referenceResolutionLevel,
            overallLevel: overallLevel,
            overallLabel: overallLabel(for: overallLevel)
        )
    }

    /// `.critical` beats `.warning` beats `.neutral`/`.informational` beats
    /// `.healthy` -- the single worst level found wins, so one red row
    /// always turns the overall indicator red.
    private static func worst(of levels: [HealthLevel]) -> HealthLevel {
        if levels.contains(.critical) { return .critical }
        if levels.contains(.warning) { return .warning }
        if levels.contains(.healthy) { return .healthy }
        return .neutral
    }

    private static func overallLabel(for level: HealthLevel) -> String {
        switch level {
        case .healthy: return "All Systems Healthy"
        case .warning: return "Attention Needed"
        case .critical: return "Disconnected"
        case .informational, .neutral: return "Waiting for Data"
        }
    }
}
