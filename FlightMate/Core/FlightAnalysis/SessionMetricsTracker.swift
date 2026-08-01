//
//  SessionMetricsTracker.swift
//  FlightMate
//
//  Default SessionMetricsTracking implementation.
//

import Foundation

/// Default `SessionMetricsTracking` implementation.
///
/// Distance accumulation uses a small private haversine calculation
/// rather than `Core/Airport/GeoDistance.swift`, deliberately keeping this
/// collaborator free of any dependency on (or need to touch) a completed
/// milestone's file -- the formula is ~10 lines and already precedented
/// elsewhere in this codebase.
final class SessionMetricsTracker: SessionMetricsTracking {
    private(set) var metrics = SessionMetrics()

    private var lastAircraftCode: String?
    private var lastDepartureCode: String?
    private var lastPosition: GeoCoordinate?

    /// Running sum/count backing `metrics.averageGroundSpeedKnots`. Kept
    /// as private tracker state (not on `SessionMetrics` itself) since
    /// they're bookkeeping for this running mean, not a metric anyone
    /// downstream should read directly.
    private var groundSpeedSampleSumKnots: Double = 0
    private var groundSpeedSampleCount: Int = 0

    private let now: () -> Date

    /// - Parameter now: Injected clock, mirroring `AeroflySessionService`'s
    ///   pattern, so tests can control elapsed time deterministically.
    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func record(_ context: FlightContext) {
        let currentAircraftCode = context.aeroflySession?.aircraft?.aeroflyCode
        let currentDepartureCode = context.aeroflySession?.departure?.airportCode

        if identityChanged(previous: lastAircraftCode, current: currentAircraftCode)
            || identityChanged(previous: lastDepartureCode, current: currentDepartureCode) {
            resetForNewSession()
        }

        if let currentAircraftCode {
            lastAircraftCode = currentAircraftCode
        }
        if let currentDepartureCode {
            lastDepartureCode = currentDepartureCode
        }

        if metrics.flightStartDate == nil {
            metrics.flightStartDate = now()
        }
        if let flightStartDate = metrics.flightStartDate {
            metrics.durationSeconds = now().timeIntervalSince(flightStartDate)
        }

        accumulateDistance(to: context.bestKnownPosition)
        accumulateAltitudeAndSpeed(altitudeMeters: context.altitudeMeters, groundSpeedMetersPerSecond: context.groundSpeedMetersPerSecond)
    }

    // MARK: - Reset rules

    /// A transient `nil` (identity temporarily unknown) never triggers a
    /// reset and never clears the last-known code -- only a previously
    /// known identity changing to a *different*, also-known identity
    /// counts. If neither aircraft nor departure is known yet, tracking
    /// simply keeps accumulating until a future Flight Event Engine
    /// provides firmer session boundaries.
    private func identityChanged(previous: String?, current: String?) -> Bool {
        guard let previous, let current else { return false }
        return previous != current
    }

    private func resetForNewSession() {
        metrics = SessionMetrics()
        lastPosition = nil
        groundSpeedSampleSumKnots = 0
        groundSpeedSampleCount = 0
    }

    // MARK: - Distance accumulation

    private func accumulateDistance(to currentPosition: GeoCoordinate?) {
        defer {
            if let currentPosition {
                lastPosition = currentPosition
            }
        }

        guard let previousPosition = lastPosition, let currentPosition else { return }

        let delta = Self.haversineNauticalMiles(from: previousPosition, to: currentPosition)
        guard delta > FlightAnalysisConstants.distanceNoiseFloorNm else { return }

        metrics.distanceTraveledNauticalMiles += delta
    }

    // MARK: - Altitude / speed accumulation

    /// Updates the running max altitude, max ground speed, and mean
    /// ground speed for the current session. Each input is independent
    /// (a `nil` altitude doesn't block updating ground speed, and vice
    /// versa) since `XGPS` always carries both together in practice, but
    /// nothing here should assume that.
    private func accumulateAltitudeAndSpeed(altitudeMeters: Double?, groundSpeedMetersPerSecond: Double?) {
        if let altitudeMeters {
            let altitudeFeet = UnitConversion.feet(fromMeters: altitudeMeters)
            metrics.maxAltitudeFeet = max(metrics.maxAltitudeFeet ?? altitudeFeet, altitudeFeet)
        }

        if let groundSpeedMetersPerSecond {
            let groundSpeedKnots = UnitConversion.knots(fromMetersPerSecond: groundSpeedMetersPerSecond)
            metrics.maxGroundSpeedKnots = max(metrics.maxGroundSpeedKnots ?? groundSpeedKnots, groundSpeedKnots)

            groundSpeedSampleSumKnots += groundSpeedKnots
            groundSpeedSampleCount += 1
            metrics.averageGroundSpeedKnots = groundSpeedSampleSumKnots / Double(groundSpeedSampleCount)
        }
    }

    /// Tiny, self-contained haversine calculation -- see this type's doc
    /// header for why it doesn't call `GeoDistance.nauticalMiles(...)`.
    private static func haversineNauticalMiles(from: GeoCoordinate, to: GeoCoordinate) -> Double {
        let earthRadiusNauticalMiles = 3_440.065
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())

        return earthRadiusNauticalMiles * c
    }
}
