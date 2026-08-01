//
//  FlightHistoryListItem.swift
//  FlightMate
//
//  One row in the Flight History list: either a rich, in-memory
//  FlightHistory from this app session (full event timeline), or a
//  flattened PersistedFlightRecord read back from a previous session.
//  Kept as a display-layer union rather than forcing PersistedFlightRecord
//  to fake a FlightHistory (it has no event timeline to fake) or
//  FlightHistory to become SwiftData-aware.
//

import Foundation

enum FlightHistoryListItem: Identifiable {
    case live(FlightHistory)
    case persisted(PersistedFlightRecord)

    var id: UUID {
        switch self {
        case .live(let history): return history.id
        case .persisted(let record): return record.id
        }
    }

    var startTime: Date {
        switch self {
        case .live(let history): return history.startTime
        case .persisted(let record): return record.startTime
        }
    }

    var status: FlightHistoryStatus {
        switch self {
        case .live(let history): return history.status
        case .persisted(let record): return record.status
        }
    }

    var hasStartedFlight: Bool {
        switch self {
        case .live(let history): return history.hasStartedFlight
        case .persisted: return true // Only started flights are ever persisted -- see FlightHistoryPersistenceService.
        }
    }

    var aircraftLabel: String {
        switch self {
        case .live(let history):
            return history.currentAircraft?.aircraft?.nameFull ?? history.currentAircraft?.aircraftCode ?? "Unknown aircraft"
        case .persisted(let record):
            return record.aircraftName ?? record.aircraftCode ?? "Unknown aircraft"
        }
    }

    var departureICAO: String? {
        switch self {
        case .live(let history): return history.departureAirport?.icaoCode
        case .persisted(let record): return record.departureICAO
        }
    }

    var destinationICAO: String? {
        switch self {
        case .live(let history): return history.destinationAirport?.icaoCode
        case .persisted(let record): return record.destinationICAO
        }
    }

    var takeoffTime: Date? {
        switch self {
        case .live(let history): return history.takeoffTime
        case .persisted(let record): return record.takeoffTime
        }
    }

    var flightDurationSeconds: TimeInterval? {
        switch self {
        case .live(let history): return history.flightDurationSeconds
        case .persisted(let record): return record.flightDurationSeconds
        }
    }

    var maxAltitudeFeet: Double? {
        switch self {
        case .live(let history): return history.maxAltitudeFeet
        case .persisted(let record): return record.maxAltitudeFeet
        }
    }

    var maxGroundSpeedKnots: Double? {
        switch self {
        case .live(let history): return history.maxGroundSpeedKnots
        case .persisted(let record): return record.maxGroundSpeedKnots
        }
    }

    var averageGroundSpeedKnots: Double? {
        switch self {
        case .live(let history): return history.averageGroundSpeedKnots
        case .persisted(let record): return record.averageGroundSpeedKnots
        }
    }

    /// Full event timeline, if this item has one -- only `.live` histories
    /// carry a timeline; a `PersistedFlightRecord` is a flattened summary.
    var events: [FlightEvent]? {
        switch self {
        case .live(let history): return history.events
        case .persisted: return nil
        }
    }
}
