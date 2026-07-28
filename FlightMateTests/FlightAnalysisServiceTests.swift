//
//  FlightAnalysisServiceTests.swift
//  FlightMateTests
//
//  Pure-function tests for FlightAnalysisService -- no networking, no
//  timers. Every input is passed in directly, so these run instantly and
//  deterministically.
//

import Foundation
import Testing
@testable import FlightMate

struct FlightAnalysisServiceTests {

    // MARK: - Telemetry health

    @Test func telemetryHealthIsNotConnectedWhenNotListening() {
        let context = makeContext(connectionStatus: .idle)
        #expect(FlightAnalysisService.telemetryHealth(context: context, now: Date()) == .notConnected)
    }

    @Test func telemetryHealthIsAcquiringWhenListeningWithoutAnyPacket() {
        let context = makeContext(connectionStatus: .listening, lastUpdated: nil)
        #expect(FlightAnalysisService.telemetryHealth(context: context, now: Date()) == .acquiring)
    }

    @Test func telemetryHealthIsLiveWithinFreshnessWindow() {
        let now = Date()
        let context = makeContext(connectionStatus: .listening, lastUpdated: now.addingTimeInterval(-1))
        #expect(FlightAnalysisService.telemetryHealth(context: context, now: now) == .live)
    }

    @Test func telemetryHealthIsStaleBeyondFreshnessWindow() {
        let now = Date()
        let context = makeContext(connectionStatus: .listening, lastUpdated: now.addingTimeInterval(-10))
        #expect(FlightAnalysisService.telemetryHealth(context: context, now: now) == .stale(secondsSinceLastUpdate: 10))
    }

    // MARK: - Vertical speed

    @Test func verticalSpeedComputedFromConsecutiveAltitudes() {
        let t0 = Date()
        let previous = makeContext(altitudeMeters: 1_000, lastUpdated: t0)
        let current = makeContext(altitudeMeters: 1_010, lastUpdated: t0.addingTimeInterval(1))

        let result = FlightAnalysisService.verticalSpeedFeetPerMinute(current: current, previous: previous, previousAnalysis: .idle)

        // 10 meters in 1 second == ~32.8 ft in 1/60 minute == ~1968.5 fpm.
        #expect(result != nil)
        #expect(abs(result! - 1_968.5) < 1.0)
    }

    @Test func verticalSpeedCarriesForwardWhenSampleIntervalTooSmall() {
        var previousAnalysis = FlightAnalysis.idle
        previousAnalysis.estimatedVerticalSpeedFeetPerMinute = 500

        let t0 = Date()
        let previous = makeContext(altitudeMeters: 1_000, lastUpdated: t0)
        let current = makeContext(altitudeMeters: 1_010, lastUpdated: t0.addingTimeInterval(0.1))

        let result = FlightAnalysisService.verticalSpeedFeetPerMinute(current: current, previous: previous, previousAnalysis: previousAnalysis)
        #expect(result == 500)
    }

    @Test func verticalSpeedCarriesForwardWhenNoPreviousContext() {
        var previousAnalysis = FlightAnalysis.idle
        previousAnalysis.estimatedVerticalSpeedFeetPerMinute = 123

        let current = makeContext(altitudeMeters: 1_000, lastUpdated: Date())
        let result = FlightAnalysisService.verticalSpeedFeetPerMinute(current: current, previous: nil, previousAnalysis: previousAnalysis)
        #expect(result == 123)
    }

    // MARK: - Ground track

    @Test func groundTrackComputedFromConsecutivePositions() {
        let t0 = Date()
        let previous = makeContext(latitude: 0, longitude: 0, lastUpdated: t0)
        let current = makeContext(latitude: 0, longitude: 1, lastUpdated: t0.addingTimeInterval(1))

        let result = FlightAnalysisService.groundTrackDegreesTrue(current: current, previous: previous, previousAnalysis: .idle)
        // Due east along the equator.
        #expect(result != nil)
        #expect(abs(result! - 90) < 0.01)
    }

    @Test func groundTrackCarriesForwardWhenPositionUnchanged() {
        var previousAnalysis = FlightAnalysis.idle
        previousAnalysis.estimatedGroundTrackDegreesTrue = 42

        let t0 = Date()
        let previous = makeContext(latitude: 0, longitude: 0, lastUpdated: t0)
        let current = makeContext(latitude: 0, longitude: 0, lastUpdated: t0.addingTimeInterval(1))

        let result = FlightAnalysisService.groundTrackDegreesTrue(current: current, previous: previous, previousAnalysis: previousAnalysis)
        #expect(result == 42)
    }

    // MARK: - Turn detection

    @Test func isTurningDetectsRateAboveThreshold() {
        let t0 = Date()
        let previous = makeContext(headingDegreesTrue: 0, lastUpdated: t0)
        let current = makeContext(headingDegreesTrue: 10, lastUpdated: t0.addingTimeInterval(1))

        #expect(FlightAnalysisService.isTurning(current: current, previous: previous, previousAnalysis: .idle))
    }

    @Test func isTurningFalseBelowThreshold() {
        let t0 = Date()
        let previous = makeContext(headingDegreesTrue: 0, lastUpdated: t0)
        let current = makeContext(headingDegreesTrue: 1, lastUpdated: t0.addingTimeInterval(1))

        #expect(!FlightAnalysisService.isTurning(current: current, previous: previous, previousAnalysis: .idle))
    }

    @Test func isTurningHandlesHeadingWraparound() {
        let t0 = Date()
        // 359 -> 3 is a +4 degree turn through the 0/360 boundary, not a
        // -356 degree turn the other way around.
        let previous = makeContext(headingDegreesTrue: 359, lastUpdated: t0)
        let current = makeContext(headingDegreesTrue: 3, lastUpdated: t0.addingTimeInterval(1))

        #expect(FlightAnalysisService.isTurning(current: current, previous: previous, previousAnalysis: .idle))
    }

    // MARK: - Analysis confidence

    @Test func confidenceIsHighWhenAllCoreFactorsAreGood() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: true),
            resolvedDestination: nil,
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .live
        )

        #expect(result.level == .high)
        #expect(result.reasons.contains("Aircraft resolved"))
        #expect(result.reasons.contains("Nearest airport known"))
        #expect(result.reasons.contains("Fresh telemetry"))
    }

    @Test func confidenceHighReasonsIncludeResolvedDestinationAsBonus() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: true),
            resolvedDestination: makeResolvedAirport(known: true),
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .live
        )

        #expect(result.level == .high)
        #expect(result.reasons.contains("Destination resolved"))
    }

    @Test func confidenceIsLowWhenAircraftUnknown() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: false),
            resolvedDestination: nil,
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .live
        )

        #expect(result.level == .low)
        #expect(result.reasons.contains("Aircraft unknown"))
    }

    @Test func confidenceIsLowWhenTelemetryStale() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: true),
            resolvedDestination: nil,
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .stale(secondsSinceLastUpdate: 10)
        )

        #expect(result.level == .low)
        #expect(result.reasons.contains("Telemetry stale"))
    }

    @Test func confidenceNeverPenalizesAnAbsentFlightPlan() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: false),
            resolvedDestination: nil, // no flight plan set -- normal, not a gap
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .live
        )

        #expect(result.level == .low)
        #expect(!result.reasons.contains("Destination unavailable"))
    }

    @Test func confidencePenalizesAnUnresolvedDestinationReference() {
        let result = FlightAnalysisService.confidence(
            resolvedAircraft: makeResolvedAircraft(known: false),
            resolvedDestination: makeResolvedAirport(known: false), // referenced but didn't resolve
            nearestAirport: makeResolvedAirport(known: true),
            telemetryHealth: .live
        )

        #expect(result.level == .low)
        #expect(result.reasons.contains("Destination unavailable"))
    }

    // MARK: - FlightPerformanceProfile

    @Test func performanceProfileUsesResolvedAircraftData() {
        let profile = FlightPerformanceProfile.make(from: makeResolvedAircraft(known: true))
        #expect(profile.source == .resolvedAircraft)
        #expect(profile.cruiseSpeedKts == ReferenceDataFixtures.a320.cruiseSpeedKts)
        #expect(profile.approachAirspeedKts == ReferenceDataFixtures.a320.approachAirspeedKts)
        #expect(profile.cruiseAltitudeFt == ReferenceDataFixtures.a320.cruiseAltitudeFt)
    }

    @Test func performanceProfileFallsBackWhenAircraftUnresolved() {
        let profile = FlightPerformanceProfile.make(from: makeResolvedAircraft(known: false))
        #expect(profile == .genericFallback)
    }

    @Test func performanceProfileFallsBackWhenNoAircraftSelectionAtAll() {
        let profile = FlightPerformanceProfile.make(from: nil)
        #expect(profile == .genericFallback)
    }
}

// MARK: - Test helpers

private func makeContext(
    latitude: Double? = nil,
    longitude: Double? = nil,
    altitudeMeters: Double? = nil,
    headingDegreesTrue: Double? = nil,
    groundSpeedMetersPerSecond: Double? = nil,
    connectionStatus: TelemetryConnectionStatus = .listening,
    lastUpdated: Date? = nil
) -> FlightContext {
    FlightContext(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        headingDegreesTrue: headingDegreesTrue,
        groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
        connectionStatus: connectionStatus,
        lastUpdated: lastUpdated
    )
}

private func makeResolvedAircraft(known: Bool) -> ResolvedAircraft {
    ResolvedAircraft(
        aircraftCode: "a320_neo",
        liveryCode: "",
        aircraft: known ? ReferenceDataFixtures.a320 : nil,
        livery: nil
    )
}

private func makeResolvedAirport(known: Bool) -> ResolvedAirport {
    ResolvedAirport(
        icaoCode: "AAAA",
        runwayIdentifier: nil,
        airport: known ? ReferenceDataFixtures.origin : nil,
        runway: nil,
        country: nil
    )
}
