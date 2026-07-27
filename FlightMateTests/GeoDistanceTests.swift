//
//  GeoDistanceTests.swift
//  FlightMateTests
//
//  Exercises GeoDistance.nauticalMiles(from:to:) — a pure function with no
//  external dependencies.
//

import Testing
@testable import FlightMate

struct GeoDistanceTests {

    @Test func distanceBetweenIdenticalPointsIsZero() {
        let point = GeoCoordinate(latitude: 37.6188, longitude: -122.3750)

        #expect(GeoDistance.nauticalMiles(from: point, to: point) == 0)
    }

    @Test func oneDegreeOfLongitudeAtEquatorIsApproximatelySixtyNauticalMiles() {
        let a = GeoCoordinate(latitude: 0, longitude: 0)
        let b = GeoCoordinate(latitude: 0, longitude: 1)

        let distance = GeoDistance.nauticalMiles(from: a, to: b)

        #expect(abs(distance - 60.04) < 0.1)
    }

    @Test func distanceIsSymmetric() {
        let a = GeoCoordinate(latitude: 51.4700, longitude: -0.4543)
        let b = GeoCoordinate(latitude: 40.6413, longitude: -73.7781)

        let forward = GeoDistance.nauticalMiles(from: a, to: b)
        let backward = GeoDistance.nauticalMiles(from: b, to: a)

        #expect(abs(forward - backward) < 0.0001)
        #expect(forward > 2_000 && forward < 3_500)
    }
}
