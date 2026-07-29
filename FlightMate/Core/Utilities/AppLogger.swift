//
//  AppLogger.swift
//  FlightMate
//
//  Centralized logging namespace shared across Core services and Features.
//

import Foundation
import OSLog

/// Centralized logging for FlightMate, backed by `os.Logger`.
///
/// Loggers are split by subsystem/category so output can be filtered easily
/// in Console.app. Add a new `static let` here per subsystem as more of the
/// app comes online.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.flightmate.app"

    /// Logs related to raw UDP transport and telemetry packet parsing.
    static let telemetry = Logger(subsystem: subsystem, category: "Telemetry")

    /// Logs related to loading and decoding bundled reference data
    /// (airports, aircraft).
    static let referenceData = Logger(subsystem: subsystem, category: "ReferenceData")

    /// Logs related to guided-procedure knowledge JSON under Resources/Knowledge.
    static let knowledge = Logger(subsystem: subsystem, category: "Knowledge")

    /// Logs related to locating, watching, and parsing Aerofly's session
    /// files (main.mcf, tm.log) — see `AeroflySessionService`.
    static let aeroflySession = Logger(subsystem: subsystem, category: "AeroflySession")
}
