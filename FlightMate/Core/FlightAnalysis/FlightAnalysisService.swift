//
//  FlightAnalysisService.swift
//  FlightMate
//
//  Pure interpretation logic: turns a FlightContext (plus resolved
//  session/reference data and previous state) into a FlightAnalysis. No
//  networking, no timers, no shared state -- everything needed is passed
//  in as arguments, which is what keeps this trivially unit-testable.
//
//  FlightAnalysisEngine (stateful) is the only caller -- see that type for
//  how resolvedSession/nearestAirport/sessionMetrics are produced.
//

import Foundation

/// Stateless interpretation of one flight-context observation into a
/// `FlightAnalysis`.
///
/// Named `FlightAnalysisService` (not `FlightAnalyzer`) so the pipeline
/// reads unambiguously: `FlightAnalysisEngine` (stateful orchestrator) ->
/// `FlightAnalysisService` (pure logic) -> `FlightAnalysis` (output).
enum FlightAnalysisService {
    private static let metersToFeet = 3.28084
    private static let metersPerSecondToKnots = 1.94384

    /// Produces a new `FlightAnalysis` from one `FlightContext`
    /// observation.
    ///
    /// - Parameters:
    ///   - currentContext: The latest `FlightContext`.
    ///   - previousContext: The context immediately before `currentContext`,
    ///     used to compute rates (vertical speed, ground track, turn
    ///     rate). `nil` on the very first observation.
    ///   - previousAnalysis: The last published `FlightAnalysis`, used both
    ///     as the phase state machine's hysteresis input and to carry
    ///     forward rate estimates when a fresh sample can't be computed.
    ///   - resolvedSession: The current Aerofly session, fully resolved
    ///     into domain objects (never raw codes) -- `nil` if no session is
    ///     known yet.
    ///   - nearestAirport: The nearest airport to `currentContext`'s
    ///     position, already resolved -- `nil` if no position or no
    ///     bundled airport data.
    ///   - sessionMetrics: Cumulative distance/duration for the current
    ///     session, from `SessionMetricsTracking`.
    ///   - now: The current time, injected for testability.
    static func analyze(
        currentContext: FlightContext,
        previousContext: FlightContext?,
        previousAnalysis: FlightAnalysis,
        resolvedSession: ResolvedSession?,
        nearestAirport: ResolvedAirport?,
        sessionMetrics: SessionMetrics,
        now: Date
    ) -> FlightAnalysis {
        let health = telemetryHealth(context: currentContext, now: now)

        let verticalSpeed = verticalSpeedFeetPerMinute(
            current: currentContext, previous: previousContext, previousAnalysis: previousAnalysis
        )
        let groundTrack = groundTrackDegreesTrue(
            current: currentContext, previous: previousContext, previousAnalysis: previousAnalysis
        )
        let turning = isTurning(
            current: currentContext, previous: previousContext, previousAnalysis: previousAnalysis
        )

        let isClimbing = (verticalSpeed ?? 0) > FlightAnalysisConstants.verticalSpeedDeadbandFpm
        let isDescending = (verticalSpeed ?? 0) < -FlightAnalysisConstants.verticalSpeedDeadbandFpm

        let distance = distanceToNearestAirport(
            position: currentContext.bestKnownPosition, nearestAirport: nearestAirport
        )

        let profile = FlightPerformanceProfile.make(from: resolvedSession?.aircraft)

        let phaseInputs = PhaseInputs(
            groundSpeedKts: currentContext.groundSpeedMetersPerSecond.map { $0 * metersPerSecondToKnots },
            altitudeFeet: currentContext.altitudeMeters.map { $0 * metersToFeet },
            isClimbing: isClimbing,
            isDescending: isDescending,
            distanceToNearestAirportNauticalMiles: distance,
            performanceProfile: profile,
            previousPhase: previousAnalysis.flightPhase
        )
        let (phase, phaseReasons) = determinePhase(phaseInputs)

        let confidenceResult = confidence(
            resolvedAircraft: resolvedSession?.aircraft,
            resolvedDestination: resolvedSession?.destination,
            nearestAirport: nearestAirport,
            telemetryHealth: health
        )

        return FlightAnalysis(
            flightPhase: phase,
            phaseReasons: phaseReasons,
            isClimbing: isClimbing,
            isDescending: isDescending,
            isTurning: turning,
            estimatedVerticalSpeedFeetPerMinute: verticalSpeed,
            estimatedGroundTrackDegreesTrue: groundTrack,
            estimatedSessionDistanceNauticalMiles: sessionMetrics.distanceTraveledNauticalMiles,
            estimatedSessionDurationSeconds: sessionMetrics.durationSeconds,
            nearestAirport: nearestAirport,
            distanceToNearestAirportNauticalMiles: distance,
            telemetryHealth: health,
            confidence: confidenceResult,
            analysisTimestamp: now
        )
    }

    // MARK: - Telemetry health

    static func telemetryHealth(context: FlightContext, now: Date) -> TelemetryHealth {
        guard context.connectionStatus == .listening else { return .notConnected }
        guard let lastUpdated = context.lastUpdated else { return .acquiring }

        let elapsed = now.timeIntervalSince(lastUpdated)
        guard elapsed <= FlightAnalysisConstants.telemetryFreshnessWindowSeconds else {
            return .stale(secondsSinceLastUpdate: elapsed)
        }
        return .live
    }

    // MARK: - Rate estimation (vertical speed / ground track / turn rate)

    /// Δaltitude/Δt, gated by `minimumSampleIntervalSeconds` so GPS/attitude
    /// jitter between rapid packets doesn't produce noisy spikes. Carries
    /// the previous estimate forward when there isn't enough new
    /// information to recompute.
    static func verticalSpeedFeetPerMinute(
        current: FlightContext, previous: FlightContext?, previousAnalysis: FlightAnalysis
    ) -> Double? {
        guard let previous,
              let currentAltitude = current.altitudeMeters, let previousAltitude = previous.altitudeMeters,
              let currentTime = current.lastUpdated, let previousTime = previous.lastUpdated
        else {
            return previousAnalysis.estimatedVerticalSpeedFeetPerMinute
        }

        let deltaSeconds = currentTime.timeIntervalSince(previousTime)
        guard deltaSeconds >= FlightAnalysisConstants.minimumSampleIntervalSeconds else {
            return previousAnalysis.estimatedVerticalSpeedFeetPerMinute
        }

        let deltaFeet = (currentAltitude - previousAltitude) * metersToFeet
        return deltaFeet / (deltaSeconds / 60)
    }

    /// Initial bearing between consecutive `bestKnownPosition`s, same
    /// gating pattern as vertical speed.
    static func groundTrackDegreesTrue(
        current: FlightContext, previous: FlightContext?, previousAnalysis: FlightAnalysis
    ) -> Double? {
        guard let previous,
              let currentPosition = current.bestKnownPosition, let previousPosition = previous.bestKnownPosition,
              let currentTime = current.lastUpdated, let previousTime = previous.lastUpdated
        else {
            return previousAnalysis.estimatedGroundTrackDegreesTrue
        }

        let deltaSeconds = currentTime.timeIntervalSince(previousTime)
        guard deltaSeconds >= FlightAnalysisConstants.minimumSampleIntervalSeconds else {
            return previousAnalysis.estimatedGroundTrackDegreesTrue
        }

        return GeoBearing.degreesTrue(from: previousPosition, to: currentPosition)
            ?? previousAnalysis.estimatedGroundTrackDegreesTrue
    }

    /// Δheading/Δt vs `turnRateThresholdDegreesPerSecond`, wraparound-safe
    /// at the 0/360 boundary. Same gating and carry-forward pattern as the
    /// rate estimates above.
    static func isTurning(
        current: FlightContext, previous: FlightContext?, previousAnalysis: FlightAnalysis
    ) -> Bool {
        guard let previous,
              let currentHeading = current.headingDegreesTrue, let previousHeading = previous.headingDegreesTrue,
              let currentTime = current.lastUpdated, let previousTime = previous.lastUpdated
        else {
            return previousAnalysis.isTurning
        }

        let deltaSeconds = currentTime.timeIntervalSince(previousTime)
        guard deltaSeconds >= FlightAnalysisConstants.minimumSampleIntervalSeconds else {
            return previousAnalysis.isTurning
        }

        let rawDelta = currentHeading - previousHeading
        // Normalize into (-180, 180] so a crossing like 359 -> 1 reads as
        // +2 degrees, not -358.
        let wrappedDelta = ((rawDelta + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180
        let ratePerSecond = abs(wrappedDelta) / deltaSeconds

        return ratePerSecond >= FlightAnalysisConstants.turnRateThresholdDegreesPerSecond
    }

    // MARK: - Nearest airport distance

    static func distanceToNearestAirport(
        position: GeoCoordinate?, nearestAirport: ResolvedAirport?
    ) -> Double? {
        guard let position, let airport = nearestAirport?.airport else { return nil }
        return GeoDistance.nauticalMiles(from: position, to: airport.coordinate)
    }

    // MARK: - Analysis confidence

    /// `.high` requires all three core factors (aircraft resolved,
    /// nearest airport known, telemetry live). A resolved destination is
    /// a non-gating bonus reason; a destination that was *referenced but
    /// failed to resolve* is a penalty reason. A destination that simply
    /// doesn't exist (no flight plan set) is never penalized -- that's a
    /// normal, expected state, not a resolution gap.
    static func confidence(
        resolvedAircraft: ResolvedAircraft?,
        resolvedDestination: ResolvedAirport?,
        nearestAirport: ResolvedAirport?,
        telemetryHealth: TelemetryHealth
    ) -> AnalysisConfidence {
        let aircraftResolved = resolvedAircraft?.status == .resolved
        let nearestAirportKnown = nearestAirport != nil
        let telemetryLive = telemetryHealth == .live

        if aircraftResolved, nearestAirportKnown, telemetryLive {
            var reasons = ["Aircraft resolved", "Nearest airport known", "Fresh telemetry"]
            if resolvedDestination?.status == .resolved {
                reasons.append("Destination resolved")
            }
            return AnalysisConfidence(level: .high, reasons: reasons)
        }

        var reasons: [String] = []
        if !aircraftResolved { reasons.append("Aircraft unknown") }
        if !nearestAirportKnown { reasons.append("Nearest airport unknown") }
        if !telemetryLive { reasons.append(telemetryUnhealthyReason(telemetryHealth)) }
        if let resolvedDestination, resolvedDestination.status != .resolved {
            reasons.append("Destination unavailable")
        }
        return AnalysisConfidence(level: .low, reasons: reasons)
    }

    private static func telemetryUnhealthyReason(_ health: TelemetryHealth) -> String {
        switch health {
        case .notConnected: return "Telemetry not connected"
        case .acquiring: return "Telemetry acquiring"
        case .stale: return "Telemetry stale"
        case .live: return "" // unreachable -- only called when telemetryLive is false
        }
    }
}
