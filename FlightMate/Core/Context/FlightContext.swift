//
//  FlightContext.swift
//  FlightMate
//
//  Aggregates telemetry into a single contextual snapshot that the AI
//  companion will eventually reason about.
//

import Foundation

/// A unified, point-in-time snapshot of the current flight, built by
/// merging the latest `XGPSPacket` and `XATTPacket` telemetry.
///
/// Position/speed fields (from `XGPS`) and attitude fields (from `XATT`)
/// arrive as independent packets on independent schedules, so every field
/// here is optional: it is `nil` until at least one packet contributing
/// that field has been received.
///
/// This type intentionally holds only raw flight data — it does not yet
/// reason about the flight (that is `AIService`'s job, layered on top,
/// once it exists).
struct FlightContext: Equatable {

    /// Latitude, in degrees. Positive is north. `nil` until a `XGPS` packet
    /// has been received.
    var latitude: Double?

    /// Longitude, in degrees. Positive is east. `nil` until a `XGPS` packet
    /// has been received.
    var longitude: Double?

    /// Altitude above mean sea level, in meters. `nil` until a `XGPS`
    /// packet has been received.
    var altitudeMeters: Double?

    /// True heading, in degrees (0–360). Sourced from `XATT`, since it
    /// reflects the aircraft's actual heading rather than ground track.
    /// `nil` until a `XATT` packet has been received.
    var headingDegreesTrue: Double?

    /// Ground speed, in meters per second. `nil` until a `XGPS` packet has
    /// been received.
    var groundSpeedMetersPerSecond: Double?

    /// Pitch, in degrees. Positive is nose up. `nil` until a `XATT` packet
    /// has been received.
    var pitchDegrees: Double?

    /// Roll, in degrees. Positive is right wing down. `nil` until a `XATT`
    /// packet has been received.
    var rollDegrees: Double?

    /// Health of the underlying UDP telemetry connection. Unlike the fields
    /// above, this is always meaningful, even before any packet arrives.
    var connectionStatus: TelemetryConnectionStatus

    /// When this context was last updated by an incoming packet. `nil`
    /// until the first packet has been received.
    var lastUpdated: Date?

    /// A context with no telemetry yet received and an idle connection.
    static let empty = FlightContext(connectionStatus: .idle)

    /// Returns a copy of `self` with `packet`'s fields merged in and
    /// ``lastUpdated`` refreshed.
    ///
    /// Fields not carried by `packet`'s type are left untouched, so
    /// `FlightContext` accumulates a complete picture across the
    /// independently-arriving `XGPS` and `XATT` packet streams rather than
    /// resetting on every update.
    ///
    /// This is a pure function with no dependency on the telemetry pipeline,
    /// which keeps it trivially unit-testable — see `FlightContextEngine`
    /// for the stateful wrapper that calls this as packets arrive.
    ///
    /// - Returns: `self`, unchanged, if `packet` is of a type
    ///   `FlightContext` does not currently know how to merge.
    func merging(_ packet: any TelemetryPacket) -> FlightContext {
        var updated = self

        switch packet {
        case let gps as XGPSPacket:
            updated.latitude = gps.latitude
            updated.longitude = gps.longitude
            updated.altitudeMeters = gps.altitudeMeters
            updated.groundSpeedMetersPerSecond = gps.groundSpeedMetersPerSecond

        case let att as XATTPacket:
            updated.headingDegreesTrue = att.headingDegreesTrue
            updated.pitchDegrees = att.pitchDegrees
            updated.rollDegrees = att.rollDegrees

        default:
            return self
        }

        updated.lastUpdated = Date()
        return updated
    }
}
