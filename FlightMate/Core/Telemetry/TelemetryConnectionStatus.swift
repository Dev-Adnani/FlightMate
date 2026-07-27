//
//  TelemetryConnectionStatus.swift
//  FlightMate
//
//  Represents the health of the raw UDP telemetry connection, independent of
//  whether any telemetry has actually been parsed yet.
//

import Foundation

/// The lifecycle state of `TelemetryService`'s underlying UDP listener.
///
/// This describes transport health only (is the socket bound and receiving
/// bytes?) — it says nothing about the *content* of the flight, since
/// FlightMate does not parse telemetry packets yet.
enum TelemetryConnectionStatus: Equatable {
    /// No listener has been started, or `stop()` was called.
    case idle
    /// `start(port:)` was called and the socket is being bound.
    case starting
    /// The socket is bound and actively able to receive datagrams.
    case listening
    /// The listener failed to start, or failed while running.
    /// The associated value is a human-readable description of the error.
    case failed(String)
}
