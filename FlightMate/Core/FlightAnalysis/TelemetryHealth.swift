//
//  TelemetryHealth.swift
//  FlightMate
//
//  Describes the freshness of the telemetry feeding FlightAnalysisService,
//  independent from TelemetryConnectionStatus -- a stale feed doesn't erase
//  the last known FlightPhase, but it does inform AnalysisConfidence.
//

import Foundation

/// The health of the UDP telemetry feed, as seen by the Flight Analysis
/// Engine.
///
/// Broader than `TelemetryConnectionStatus`: it also accounts for *when*
/// the last packet was received, not just whether the socket is bound.
enum TelemetryHealth: Equatable {
    /// `TelemetryConnectionStatus` is not `.listening` (idle, starting, or
    /// failed).
    case notConnected

    /// Listening, but no packet has been received yet.
    case acquiring

    /// Listening, and the last packet arrived within
    /// `FlightAnalysisConstants.telemetryFreshnessWindowSeconds`.
    case live

    /// Listening, but the last packet is older than the freshness window.
    case stale(secondsSinceLastUpdate: TimeInterval)
}
