//
//  FlightContext.swift
//  FlightMate
//
//  Aggregates telemetry into a single contextual snapshot that the AI
//  companion will eventually reason about.
//

import Foundation

/// A unified, point-in-time snapshot of the current flight, built by
/// merging live UDP telemetry with Aerofly's own session file (`main.mcf`).
///
/// ## Source precedence
///
/// `FlightContext` is fed by two completely independent, asynchronous
/// sources, plus (transitively, via `AirportService`/`AircraftService`) a
/// bundled reference database. They never have equal authority — every
/// field below has one and only one source of truth:
///
/// 1. **UDP telemetry (highest precedence)** — `latitude`, `longitude`,
///    `altitudeMeters`, `headingDegreesTrue`, `groundSpeedMetersPerSecond`,
///    `pitchDegrees`, `rollDegrees`, `connectionStatus`. Realtime, high
///    frequency. Once any of these has been observed over UDP, nothing
///    else may ever overwrite it — see `merging(_:)`.
/// 2. **Aerofly session (`main.mcf`), lower precedence** — everything
///    under `aeroflySession` (aircraft, livery, departure, destination,
///    on-ground flag, weather, simulated time, Aerofly version) plus
///    `aeroflySession.initialPosition`. Low frequency, event-driven (see
///    `AeroflySessionService`). Its position is only ever used as an
///    *initial* stand-in for UDP position, before UDP has produced one —
///    see `bestKnownPosition`. `aeroflySessionState` is the structural
///    answer to "why is `aeroflySession` nil or stale" (e.g.
///    `.fileNotFound` vs `.loaded`), and `aeroflySessionValidation` is a
///    developer-facing diagnostic of the last parse attempt.
/// 3. **Bundled reference database (lowest precedence)** — not stored on
///    `FlightContext` itself. `AirportService`/`AircraftService` resolve
///    raw codes (airport ICAOs, aircraft/livery codes) from the two
///    sources above into full domain models, purely to *enrich*
///    information that already came from telemetry or the session file.
///    `FlightContext` stays a pure data snapshot; reference-data lookups
///    are a consumer-side concern.
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

    // MARK: - Aerofly session (main.mcf) — see source precedence above

    /// The current simulator session, as last parsed from `main.mcf`.
    /// `nil` until `AeroflySessionService` has successfully parsed at
    /// least once — check `aeroflySessionState` for why.
    var aeroflySession: AeroflySession?

    /// Structural status of the Aerofly session source, independent of
    /// UDP. Defaults to `.notStarted` until an `AeroflySessionService` is
    /// wired in and started.
    var aeroflySessionState: AeroflySessionState = .notStarted

    /// Developer-facing diagnostics from the most recent `main.mcf` parse
    /// attempt (found/missing/unexpected fields). Not intended for
    /// end-user display.
    var aeroflySessionValidation: AeroflySessionValidationReport?

    /// The best currently-known position, honoring source precedence: UDP
    /// telemetry (`latitude`/`longitude`) if it has ever been observed,
    /// otherwise the Aerofly session's `initialPosition`, otherwise `nil`.
    ///
    /// Once UDP has produced a position it is always preferred here, even
    /// if a later `main.mcf` reparse republishes a session — the session's
    /// position is only ever a pre-UDP stand-in, never an override.
    var bestKnownPosition: GeoCoordinate? {
        if let latitude, let longitude {
            return GeoCoordinate(latitude: latitude, longitude: longitude)
        }
        return aeroflySession?.initialPosition
    }

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
