//
//  SessionMetricsTrackerTests.swift
//  FlightMateTests
//
//  Exercises SessionMetricsTracker's distance accumulation and reset
//  rules with an injected clock -- no real timing or disk involved.
//

import Foundation
import Testing
@testable import FlightMate

struct SessionMetricsTrackerTests {

    @Test func distanceAccumulatesAcrossConsecutivePositions() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0))
        tracker.record(makeContext(latitude: 0, longitude: 1)) // ~60 NM east at the equator

        #expect(tracker.metrics.distanceTraveledNauticalMiles > 50)
        #expect(tracker.metrics.distanceTraveledNauticalMiles < 70)
    }

    @Test func noiseFloorFiltersStationaryJitter() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0))
        // ~0.0001 degrees longitude at the equator is only a few feet --
        // well under the noise floor.
        tracker.record(makeContext(latitude: 0, longitude: 0.0001))

        #expect(tracker.metrics.distanceTraveledNauticalMiles == 0)
    }

    @Test func resetsWhenAircraftIdentityChanges() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "a320_neo"))
        tracker.record(makeContext(latitude: 0, longitude: 1, aircraftCode: "a320_neo"))
        #expect(tracker.metrics.distanceTraveledNauticalMiles > 0)

        // A different, also-known aircraft code -- a genuinely new session.
        tracker.record(makeContext(latitude: 0, longitude: 1, aircraftCode: "c172"))
        #expect(tracker.metrics.distanceTraveledNauticalMiles == 0)
    }

    @Test func resetsWhenDepartureIdentityChanges() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, departureCode: "VABB"))
        tracker.record(makeContext(latitude: 0, longitude: 1, departureCode: "VABB"))
        #expect(tracker.metrics.distanceTraveledNauticalMiles > 0)

        tracker.record(makeContext(latitude: 0, longitude: 1, departureCode: "EGPH"))
        #expect(tracker.metrics.distanceTraveledNauticalMiles == 0)
    }

    @Test func neverResetsWhenIdentityIsSimplyUnknown() {
        let tracker = SessionMetricsTracker()

        // No aircraft/departure known at all throughout -- must keep
        // accumulating rather than resetting on every transient nil.
        tracker.record(makeContext(latitude: 0, longitude: 0))
        tracker.record(makeContext(latitude: 0, longitude: 1))
        tracker.record(makeContext(latitude: 0, longitude: 2))

        #expect(tracker.metrics.distanceTraveledNauticalMiles > 100)
    }

    @Test func aTransientNilIdentityNeverTriggersAResetOrClearsTheKnownCode() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "a320_neo"))
        tracker.record(makeContext(latitude: 0, longitude: 1, aircraftCode: nil)) // transient nil
        #expect(tracker.metrics.distanceTraveledNauticalMiles > 0)

        // A genuinely different code, after the transient nil, still
        // resets -- the last *known* code ("a320_neo") was never cleared.
        tracker.record(makeContext(latitude: 0, longitude: 2, aircraftCode: "c172"))
        #expect(tracker.metrics.distanceTraveledNauticalMiles == 0)
    }

    @Test func flightStartDateIsSetOnFirstRecordAndDurationTracksInjectedClock() {
        let clock = MutableClock(start: Date(timeIntervalSince1970: 1_000))
        let tracker = SessionMetricsTracker(now: clock.now)

        tracker.record(makeContext(latitude: 0, longitude: 0))
        #expect(tracker.metrics.flightStartDate == Date(timeIntervalSince1970: 1_000))
        #expect(tracker.metrics.durationSeconds == 0)

        clock.advance(by: 90)
        tracker.record(makeContext(latitude: 0, longitude: 0))
        #expect(tracker.metrics.durationSeconds == 90)
    }

    @Test func maxAltitudeTracksTheHighestObservedSampleInFeet() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, altitudeMeters: 1_000))
        #expect(tracker.metrics.maxAltitudeFeet == UnitConversion.feet(fromMeters: 1_000))

        tracker.record(makeContext(latitude: 0, longitude: 0, altitudeMeters: 500))
        // A lower later sample must never pull the max back down.
        #expect(tracker.metrics.maxAltitudeFeet == UnitConversion.feet(fromMeters: 1_000))

        tracker.record(makeContext(latitude: 0, longitude: 0, altitudeMeters: 2_000))
        #expect(tracker.metrics.maxAltitudeFeet == UnitConversion.feet(fromMeters: 2_000))
    }

    @Test func maxGroundSpeedTracksTheHighestObservedSampleInKnots() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 50))
        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 30))
        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 80))

        #expect(tracker.metrics.maxGroundSpeedKnots == UnitConversion.knots(fromMetersPerSecond: 80))
    }

    @Test func averageGroundSpeedIsTheMeanOfEverySampleSeen() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 10))
        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 20))
        tracker.record(makeContext(latitude: 0, longitude: 0, groundSpeedMetersPerSecond: 30))

        let expectedAverage = UnitConversion.knots(fromMetersPerSecond: 20) // (10+20+30)/3
        #expect(tracker.metrics.averageGroundSpeedKnots != nil)
        #expect(abs(tracker.metrics.averageGroundSpeedKnots! - expectedAverage) < 0.0001)
    }

    @Test func altitudeAndSpeedExtremesResetAlongsideDistanceOnNewSession() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "a320_neo", altitudeMeters: 5_000, groundSpeedMetersPerSecond: 100))
        #expect(tracker.metrics.maxAltitudeFeet != nil)
        #expect(tracker.metrics.maxGroundSpeedKnots != nil)
        #expect(tracker.metrics.averageGroundSpeedKnots != nil)

        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "c172", altitudeMeters: 100, groundSpeedMetersPerSecond: 20))
        #expect(tracker.metrics.maxAltitudeFeet == UnitConversion.feet(fromMeters: 100))
        #expect(tracker.metrics.maxGroundSpeedKnots == UnitConversion.knots(fromMetersPerSecond: 20))
        #expect(tracker.metrics.averageGroundSpeedKnots == UnitConversion.knots(fromMetersPerSecond: 20))
    }

    @Test func nilAltitudeOrSpeedSamplesAreSkippedRatherThanTreatedAsZero() {
        let tracker = SessionMetricsTracker()

        tracker.record(makeContext(latitude: 0, longitude: 0, altitudeMeters: 1_000, groundSpeedMetersPerSecond: 50))
        tracker.record(makeContext(latitude: 0, longitude: 0)) // no altitude/speed this sample

        #expect(tracker.metrics.maxAltitudeFeet == UnitConversion.feet(fromMeters: 1_000))
        #expect(tracker.metrics.maxGroundSpeedKnots == UnitConversion.knots(fromMetersPerSecond: 50))
        #expect(tracker.metrics.averageGroundSpeedKnots == UnitConversion.knots(fromMetersPerSecond: 50))
    }

    @Test func flightStartDateResetsAlongsideDistanceOnNewSession() {
        let clock = MutableClock(start: Date(timeIntervalSince1970: 1_000))
        let tracker = SessionMetricsTracker(now: clock.now)

        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "a320_neo"))
        clock.advance(by: 60)
        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "a320_neo"))
        #expect(tracker.metrics.durationSeconds == 60)

        clock.advance(by: 10)
        tracker.record(makeContext(latitude: 0, longitude: 0, aircraftCode: "c172"))
        #expect(tracker.metrics.flightStartDate == Date(timeIntervalSince1970: 1_070))
        #expect(tracker.metrics.durationSeconds == 0)
    }
}

// MARK: - Test helpers

private func makeContext(
    latitude: Double,
    longitude: Double,
    aircraftCode: String? = nil,
    departureCode: String? = nil,
    altitudeMeters: Double? = nil,
    groundSpeedMetersPerSecond: Double? = nil
) -> FlightContext {
    var session: AeroflySession?
    if aircraftCode != nil || departureCode != nil {
        var built = AeroflySession()
        if let aircraftCode {
            built.aircraft = AeroflySession.AircraftSelection(aeroflyCode: aircraftCode, liveryCode: "")
        }
        if let departureCode {
            built.departure = AeroflySession.RunwayReference(airportCode: departureCode, runwayIdentifier: nil)
        }
        session = built
    }

    return FlightContext(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
        connectionStatus: .listening,
        aeroflySession: session
    )
}

/// A controllable clock for deterministic `flightStartDate`/`durationSeconds`
/// assertions, mirroring the injected-`now` pattern used by
/// `AeroflySessionService`/`SessionMetricsTracker`.
private final class MutableClock {
    private var current: Date
    init(start: Date) { current = start }
    func now() -> Date { current }
    func advance(by seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}
