//
//  FlightHistoryStatus.swift
//  FlightMate
//
//  The lifecycle state of one FlightHistory record.
//

import Foundation

/// How one `FlightHistory` record's lifecycle ended, if it has.
///
/// Present on `FlightHistory` from day one rather than inferred later (e.g.
/// from "does it have an end time?") -- future milestones may add cases
/// like `.crashed`, `.cancelled`, or `.replayed`, but that only ever means
/// adding a case here, never restructuring `FlightHistory` itself.
enum FlightHistoryStatus: Equatable {
    /// Still in progress -- more events may still be appended.
    case active

    /// Ended normally: `FlightEventType.flightCompleted` was received after
    /// the aircraft had genuinely been airborne.
    case completed

    /// Ended abnormally: a new `aircraftLoaded`/`aircraftChanged` event
    /// arrived while this history was still `.active`, so it was closed
    /// out early rather than left to run forever. See
    /// `FlightHistoryService` for the exact rule.
    case aborted
}
