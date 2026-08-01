//
//  PersistedFlightRecord.swift
//  FlightMate
//
//  SwiftData model for the persistent flight logbook. A flattened summary
//  of one completed `FlightHistory` -- deliberately not a full replay of
//  its event timeline (no IGC-style track log, no per-sample telemetry).
//  If a future milestone wants full flight replay, that's a new model
//  built alongside this one, not a redesign of it.
//

import Foundation
import SwiftData

/// One permanently saved flight summary, written once a `FlightHistory`
/// finalizes (`.completed` or `.aborted`) and has actually left the
/// ground (`hasStartedFlight`) -- see `FlightHistoryPersistenceService`.
/// Read-only from the UI's perspective; nothing in the app mutates an
/// existing record after it's written.
@Model
final class PersistedFlightRecord {
    /// Same identity as the `FlightHistory` this was created from, so a
    /// flight completed and persisted in the current session can be
    /// de-duplicated against the in-memory copy still held by
    /// `FlightHistoryEngine.completedHistories`.
    @Attribute(.unique) var id: UUID

    var startTime: Date
    var endTime: Date?
    var takeoffTime: Date?

    /// Mirrors `FlightHistoryStatus`, stored as a raw string since
    /// SwiftData models can't store a plain non-`Codable` enum directly
    /// without extra ceremony -- see `status`/`FlightHistoryStatus`.
    private var statusRawValue: String

    var aircraftCode: String?
    var aircraftName: String?
    var departureICAO: String?
    var destinationICAO: String?

    var flightDurationSeconds: Double?
    var maxAltitudeFeet: Double?
    var maxGroundSpeedKnots: Double?
    var averageGroundSpeedKnots: Double?
    var distanceNauticalMiles: Double?
    var eventCount: Int

    var status: FlightHistoryStatus {
        switch statusRawValue {
        case "completed": return .completed
        case "aborted": return .aborted
        default: return .active
        }
    }

    init(
        id: UUID,
        startTime: Date,
        endTime: Date?,
        takeoffTime: Date?,
        status: FlightHistoryStatus,
        aircraftCode: String?,
        aircraftName: String?,
        departureICAO: String?,
        destinationICAO: String?,
        flightDurationSeconds: Double?,
        maxAltitudeFeet: Double?,
        maxGroundSpeedKnots: Double?,
        averageGroundSpeedKnots: Double?,
        distanceNauticalMiles: Double?,
        eventCount: Int
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.takeoffTime = takeoffTime
        switch status {
        case .completed: self.statusRawValue = "completed"
        case .aborted: self.statusRawValue = "aborted"
        case .active: self.statusRawValue = "active"
        }
        self.aircraftCode = aircraftCode
        self.aircraftName = aircraftName
        self.departureICAO = departureICAO
        self.destinationICAO = destinationICAO
        self.flightDurationSeconds = flightDurationSeconds
        self.maxAltitudeFeet = maxAltitudeFeet
        self.maxGroundSpeedKnots = maxGroundSpeedKnots
        self.averageGroundSpeedKnots = averageGroundSpeedKnots
        self.distanceNauticalMiles = distanceNauticalMiles
        self.eventCount = eventCount
    }

    /// Flattens a finalized `FlightHistory` into a persistable summary.
    /// Only ever called by `FlightHistoryPersistenceService`, and only
    /// for histories that already satisfy `hasStartedFlight` -- a
    /// preflight-only abort (aircraft loaded, never flown) isn't a real
    /// entry for the logbook.
    convenience init(summarizing history: FlightHistory) {
        self.init(
            id: history.id,
            startTime: history.startTime,
            endTime: history.endTime,
            takeoffTime: history.takeoffTime,
            status: history.status,
            aircraftCode: history.currentAircraft?.aircraftCode,
            aircraftName: history.currentAircraft?.aircraft?.nameFull,
            departureICAO: history.departureAirport?.icaoCode,
            destinationICAO: history.destinationAirport?.icaoCode,
            flightDurationSeconds: history.flightDurationSeconds(at: history.endTime ?? Date()),
            maxAltitudeFeet: history.maxAltitudeFeet,
            maxGroundSpeedKnots: history.maxGroundSpeedKnots,
            averageGroundSpeedKnots: history.averageGroundSpeedKnots,
            distanceNauticalMiles: history.events.last?.analysis.estimatedSessionDistanceNauticalMiles,
            eventCount: history.events.count
        )
    }
}
