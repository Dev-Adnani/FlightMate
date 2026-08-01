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
/// Duration is takeoff-based (Option A): no clock until the flight has
/// started (`takeoffTime`), then elapsed time ticks live while the history
/// is `.active`, and freezes at `endTime` once completed/aborted.
struct FlightDurationCardModel: Equatable {
    /// When the flight clock started -- `nil` until takeoff / first airborne.
    let takeoffTime: Date?
    /// When the flight ended -- `nil` while still active.
    let endTime: Date?
    /// `true` while an active, started flight should show a live ticking clock.
    let isLive: Bool
    /// "In Progress" / "Preflight" / "Completed" / "Aborted" / "No Active Flight"
    let flightStatusLabel: String
    let flightStatusLevel: HealthLevel
    /// Quiet secondary line: last completed flight summary, or a hint
    /// while waiting for takeoff. Never a "0 flights completed" shame line.
    let secondaryLine: String?

    /// Formatted elapsed time at `now`. `nil` until the flight clock starts.
    func durationDisplay(at now: Date = Date()) -> String? {
        guard let takeoffTime else { return nil }
        let end = endTime ?? (isLive ? now : nil)
        guard let end else { return nil }
        return Self.formattedDuration(max(0, end.timeIntervalSince(takeoffTime)))
    }

    static let empty = FlightDurationCardModel(
        takeoffTime: nil,
        endTime: nil,
        isLive: false,
        flightStatusLabel: "No Active Flight",
        flightStatusLevel: .neutral,
        secondaryLine: nil
    )

    static func from(current: FlightHistory?, completed: [FlightHistory]) -> FlightDurationCardModel {
        let lastCompletedLine = completed.last.flatMap(lastFlightLine)

        guard let current else {
            return FlightDurationCardModel(
                takeoffTime: nil,
                endTime: nil,
                isLive: false,
                flightStatusLabel: "No Active Flight",
                flightStatusLevel: .neutral,
                secondaryLine: lastCompletedLine
            )
        }

        if current.hasStartedFlight {
            let (label, level) = statusDisplay(for: current.status, hasStartedFlight: true)
            return FlightDurationCardModel(
                takeoffTime: current.takeoffTime,
                endTime: current.endTime,
                isLive: current.status == .active,
                flightStatusLabel: label,
                flightStatusLevel: level,
                secondaryLine: lastCompletedLine
            )
        }

        return FlightDurationCardModel(
            takeoffTime: nil,
            endTime: nil,
            isLive: false,
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

    static func formattedDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
