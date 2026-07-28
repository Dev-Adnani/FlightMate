//
//  GeoTrailRecordingServiceTests.swift
//  FlightMateTests
//
//  Unit tests for GeoTrailRecordingService's pure sampling/reset policy
//  -- no Combine, no engines, no telemetry involved.
//

import Foundation
import Testing
@testable import FlightMate

struct GeoTrailRecordingServiceTests {

    // MARK: - shouldRecord

    @Test func firstEverPointIsAlwaysRecorded() {
        let candidate = GeoTrailPoint(coordinate: GeoCoordinate(latitude: 1, longitude: 1), timestamp: Date())

        let result = GeoTrailRecordingService.shouldRecord(
            candidate: candidate,
            lastRecorded: nil,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        #expect(result)
    }

    @Test func pointTooCloseInBothDistanceAndTimeIsNotRecorded() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let last = GeoTrailPoint(coordinate: GeoCoordinate(latitude: 10, longitude: 10), timestamp: start)
        // A few meters away, well under the 0.05nm (~92m) threshold, and
        // only 1 second later, well under the 3-second threshold.
        let candidate = GeoTrailPoint(
            coordinate: GeoCoordinate(latitude: 10.0001, longitude: 10),
            timestamp: start.addingTimeInterval(1)
        )

        let result = GeoTrailRecordingService.shouldRecord(
            candidate: candidate,
            lastRecorded: last,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        #expect(!result)
    }

    @Test func pointFarEnoughAwayIsRecordedEvenIfRecent() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let last = GeoTrailPoint(coordinate: GeoCoordinate(latitude: 10, longitude: 10), timestamp: start)
        // ~0.1nm away (well over the 0.05nm threshold), but only
        // 1 second later -- distance alone should be enough.
        let candidate = GeoTrailPoint(
            coordinate: GeoCoordinate(latitude: 10.0017, longitude: 10),
            timestamp: start.addingTimeInterval(1)
        )

        let result = GeoTrailRecordingService.shouldRecord(
            candidate: candidate,
            lastRecorded: last,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        #expect(result)
    }

    @Test func stationaryPointIsRecordedOnceEnoughTimeHasElapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let last = GeoTrailPoint(coordinate: GeoCoordinate(latitude: 10, longitude: 10), timestamp: start)
        // Exact same coordinate, but enough time has passed.
        let candidate = GeoTrailPoint(coordinate: GeoCoordinate(latitude: 10, longitude: 10), timestamp: start.addingTimeInterval(3))

        let result = GeoTrailRecordingService.shouldRecord(
            candidate: candidate,
            lastRecorded: last,
            minimumDistanceNauticalMiles: 0.05,
            minimumIntervalSeconds: 3
        )

        #expect(result)
    }

    // MARK: - shouldReset

    @Test func noActiveFlightNeverResets() {
        #expect(!GeoTrailRecordingService.shouldReset(observedHistoryId: nil, recordingHistoryId: nil))
        #expect(!GeoTrailRecordingService.shouldReset(observedHistoryId: nil, recordingHistoryId: UUID()))
    }

    @Test func firstEverFlightResets() {
        let result = GeoTrailRecordingService.shouldReset(observedHistoryId: UUID(), recordingHistoryId: nil)
        #expect(result)
    }

    @Test func sameFlightIdentityNeverResets() {
        let id = UUID()
        let result = GeoTrailRecordingService.shouldReset(observedHistoryId: id, recordingHistoryId: id)
        #expect(!result)
    }

    @Test func aGenuinelyDifferentFlightIdentityResets() {
        let result = GeoTrailRecordingService.shouldReset(observedHistoryId: UUID(), recordingHistoryId: UUID())
        #expect(result)
    }
}
