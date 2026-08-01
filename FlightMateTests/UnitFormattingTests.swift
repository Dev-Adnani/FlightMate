//
//  UnitFormattingTests.swift
//  FlightMateTests
//
//  Pure-function tests for UnitFormatting -- every case is a plain
//  input/output check, no engines or telemetry involved.
//

import Foundation
import Testing
@testable import FlightMate

struct UnitFormattingTests {

    // MARK: - Altitude

    @Test func altitudeFormatsAsFeetUnderImperial() {
        #expect(UnitFormatting.altitude(feet: 10_000, system: .imperial) == "10000 ft")
    }

    @Test func altitudeFormatsAsMetersUnderMetric() {
        let feet = 10_000.0
        let expectedMeters = Int((feet / UnitConversion.metersToFeet).rounded())
        #expect(UnitFormatting.altitude(feet: feet, system: .metric) == "\(expectedMeters) m")
    }

    @Test func altitudeIsAnEmDashWhenNilRegardlessOfSystem() {
        #expect(UnitFormatting.altitude(feet: nil, system: .imperial) == "—")
        #expect(UnitFormatting.altitude(feet: nil, system: .metric) == "—")
    }

    // MARK: - Speed

    @Test func speedFormatsAsKnotsUnderImperial() {
        #expect(UnitFormatting.speed(knots: 120, system: .imperial) == "120 kt")
    }

    @Test func speedFormatsAsKilometersPerHourUnderMetric() {
        let knots = 120.0
        let expectedKph = Int((knots * UnitConversion.knotsToKilometersPerHour).rounded())
        #expect(UnitFormatting.speed(knots: knots, system: .metric) == "\(expectedKph) km/h")
    }

    @Test func speedIsAnEmDashWhenNil() {
        #expect(UnitFormatting.speed(knots: nil, system: .imperial) == "—")
    }

    // MARK: - Vertical speed

    @Test func verticalSpeedIncludesAPlusSignWhenClimbing() {
        #expect(UnitFormatting.verticalSpeed(feetPerMinute: 500, system: .imperial) == "+500 fpm")
    }

    @Test func verticalSpeedOmitsThePlusSignWhenDescending() {
        #expect(UnitFormatting.verticalSpeed(feetPerMinute: -500, system: .imperial) == "-500 fpm")
    }

    @Test func verticalSpeedZeroStillGetsAPlusSign() {
        // 0 >= 0, so the "climbing or level" sign convention applies.
        #expect(UnitFormatting.verticalSpeed(feetPerMinute: 0, system: .imperial) == "+0 fpm")
    }

    @Test func verticalSpeedFormatsAsMetersPerMinuteUnderMetricPreservingSign() {
        let feetPerMinute = -600.0
        let expectedMetersPerMinute = Int((feetPerMinute / UnitConversion.metersToFeet).rounded())
        #expect(UnitFormatting.verticalSpeed(feetPerMinute: feetPerMinute, system: .metric) == "\(expectedMetersPerMinute) m/min")
    }

    @Test func verticalSpeedIsAnEmDashWhenNil() {
        #expect(UnitFormatting.verticalSpeed(feetPerMinute: nil, system: .imperial) == "—")
    }

    // MARK: - Distance

    @Test func distanceFormatsAsNauticalMilesUnderImperial() {
        #expect(UnitFormatting.distance(nauticalMiles: 42.5, system: .imperial) == "42.5 nm")
    }

    @Test func distanceFormatsAsKilometersUnderMetric() {
        let nm = 42.5
        let expectedKm = nm * UnitConversion.nauticalMilesToKilometers
        #expect(UnitFormatting.distance(nauticalMiles: nm, system: .metric) == String(format: "%.1f km", expectedKm))
    }

    @Test func distanceIsAnEmDashWhenNil() {
        #expect(UnitFormatting.distance(nauticalMiles: nil, system: .imperial) == "—")
    }
}
