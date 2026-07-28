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
struct FlightDurationCardModel: Equatable {
    /// Formatted elapsed time of the current flight, e.g. "1h 23m 04s" --
    /// `nil` while no active flight has produced a duration yet.
    let durationDisplay: String?
    /// "In Progress" / "Completed" / "Aborted" / "No Active Flight" --
    /// mirrors `FlightHistoryStatus`, plus the no-active-flight case.
    let flightStatusLabel: String
    let flightStatusLevel: HealthLevel
    /// How many flights have completed (or aborted) this app session --
    /// answers "what happened before this flight," using `FlightHistory`
    /// only, per this card's constraint.
    let completedFlightsThisSessionCount: Int

    static let empty = FlightDurationCardModel(
        durationDisplay: nil,
        flightStatusLabel: "No Active Flight",
        flightStatusLevel: .neutral,
        completedFlightsThisSessionCount: 0
    )

    static func from(current: FlightHistory?, completed: [FlightHistory]) -> FlightDurationCardModel {
        guard let current else {
            return FlightDurationCardModel(
                durationDisplay: nil,
                flightStatusLabel: "No Active Flight",
                flightStatusLevel: .neutral,
                completedFlightsThisSessionCount: completed.count
            )
        }

        let (label, level) = statusDisplay(for: current.status)
        return FlightDurationCardModel(
            durationDisplay: current.durationSeconds.map(formattedDuration),
            flightStatusLabel: label,
            flightStatusLevel: level,
            completedFlightsThisSessionCount: completed.count
        )
    }

    private static func statusDisplay(for status: FlightHistoryStatus) -> (label: String, level: HealthLevel) {
        switch status {
        case .active: return ("In Progress", .healthy)
        case .completed: return ("Completed", .informational)
        case .aborted: return ("Aborted", .warning)
        }
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
