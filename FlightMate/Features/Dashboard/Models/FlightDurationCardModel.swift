//
//  FlightDurationCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for FlightDurationCard, derived
//  entirely from FlightHistoryEngine's published state. FlightDurationCard
//  never touches FlightHistoryEngine/FlightHistory directly -- only this
//  model.
//

import Foundation

/// Everything `FlightDurationCard` needs to render, and nothing else.
///
/// Duration is takeoff-based (Option A): `nil` / "—" until
/// `takeoffDetected`, then elapsed until the latest event or completion.
struct FlightDurationCardModel: Equatable {
    /// Formatted elapsed time since takeoff, e.g. "1h 23m 04s" --
    /// `nil` until takeoff (preflight) or when no active flight exists.
    let durationDisplay: String?
    /// "In Progress" / "Preflight" / "Completed" / "Aborted" / "No Active Flight"
    let flightStatusLabel: String
    let flightStatusLevel: HealthLevel
    /// Quiet secondary line: last completed flight summary, or a hint
    /// while waiting for takeoff. Never a "0 flights completed" shame line.
    let secondaryLine: String?

    static let empty = FlightDurationCardModel(
        durationDisplay: nil,
        flightStatusLabel: "No Active Flight",
        flightStatusLevel: .neutral,
        secondaryLine: nil
    )

    static func from(current: FlightHistory?, completed: [FlightHistory]) -> FlightDurationCardModel {
        let lastCompletedLine = completed.last.flatMap(lastFlightLine)

        guard let current else {
            return FlightDurationCardModel(
                durationDisplay: nil,
                flightStatusLabel: "No Active Flight",
                flightStatusLevel: .neutral,
                secondaryLine: lastCompletedLine
            )
        }

        if current.hasStartedFlight {
            let (label, level) = statusDisplay(for: current.status, hasStartedFlight: true)
            return FlightDurationCardModel(
                durationDisplay: current.flightDurationSeconds.map(formattedDuration),
                flightStatusLabel: label,
                flightStatusLevel: level,
                secondaryLine: lastCompletedLine
            )
        }

        return FlightDurationCardModel(
            durationDisplay: nil,
            flightStatusLabel: "Preflight",
            flightStatusLevel: .informational,
            secondaryLine: "Waiting for takeoff"
        )
    }

    private static func statusDisplay(
        for status: FlightHistoryStatus,
        hasStartedFlight: Bool
    ) -> (label: String, level: HealthLevel) {
        switch status {
        case .active:
            return hasStartedFlight ? ("In Progress", .healthy) : ("Preflight", .informational)
        case .completed:
            return ("Completed", .informational)
        case .aborted:
            return ("Aborted", .warning)
        }
    }

    private static func lastFlightLine(_ history: FlightHistory) -> String? {
        guard history.status == .completed || history.status == .aborted else { return nil }
        let duration = history.flightDurationSeconds.map(formattedDuration) ?? "—"
        let label = history.status == .completed ? "Last flight" : "Last flight (aborted)"
        return "\(label) · \(duration)"
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
