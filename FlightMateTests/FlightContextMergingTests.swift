//
//  FlightContextMergingTests.swift
//  FlightMateTests
//
//  Exercises FlightContext.merging(_:) directly — a pure function with no
//  dependency on networking, so it can be tested deterministically.
//

import Foundation
import Testing
@testable import FlightMate

struct FlightContextMergingTests {

    @Test func startsEmpty() {
        let context = FlightContext.empty

        #expect(context.latitude == nil)
        #expect(context.longitude == nil)
        #expect(context.altitudeMeters == nil)
        #expect(context.headingDegreesTrue == nil)
        #expect(context.groundSpeedMetersPerSecond == nil)
        #expect(context.pitchDegrees == nil)
        #expect(context.rollDegrees == nil)
        #expect(context.lastUpdated == nil)
        #expect(context.connectionStatus == .idle)
    }

    @Test func mergingXGPSPopulatesPositionFields() {
        let gps = XGPSPacket(
            simulatorName: "Aerofly FS 4",
            fields: ["72.8754", "19.0818", "11.0", "314.1", "0.2"]
        )!

        let context = FlightContext.empty.merging(gps)

        #expect(context.longitude == 72.8754)
        #expect(context.latitude == 19.0818)
        #expect(context.altitudeMeters == 11.0)
        #expect(context.groundSpeedMetersPerSecond == 0.2)
        #expect(context.lastUpdated != nil)

        // XGPS does not carry attitude data.
        #expect(context.headingDegreesTrue == nil)
        #expect(context.pitchDegrees == nil)
        #expect(context.rollDegrees == nil)
    }

    @Test func mergingXATTPopulatesAttitudeFields() {
        let att = XATTPacket(simulatorName: "Aerofly FS 4", fields: ["314.1", "-0.23", "0.29"])!

        let context = FlightContext.empty.merging(att)

        #expect(context.headingDegreesTrue == 314.1)
        #expect(context.pitchDegrees == -0.23)
        #expect(context.rollDegrees == 0.29)
        #expect(context.lastUpdated != nil)

        // XATT does not carry position data.
        #expect(context.latitude == nil)
        #expect(context.longitude == nil)
        #expect(context.altitudeMeters == nil)
        #expect(context.groundSpeedMetersPerSecond == nil)
    }

    @Test func mergingBothPacketTypesAccumulatesFields() {
        let gps = XGPSPacket(
            simulatorName: "Aerofly FS 4",
            fields: ["72.8754", "19.0818", "11.0", "314.1", "0.2"]
        )!
        let att = XATTPacket(simulatorName: "Aerofly FS 4", fields: ["314.1", "-0.23", "0.29"])!

        let context = FlightContext.empty.merging(gps).merging(att)

        #expect(context.latitude == 19.0818)
        #expect(context.longitude == 72.8754)
        #expect(context.altitudeMeters == 11.0)
        #expect(context.groundSpeedMetersPerSecond == 0.2)
        #expect(context.headingDegreesTrue == 314.1)
        #expect(context.pitchDegrees == -0.23)
        #expect(context.rollDegrees == 0.29)
    }

    @Test func laterXATTDoesNotClearEarlierXGPSFields() {
        let gps = XGPSPacket(
            simulatorName: "Aerofly FS 4",
            fields: ["72.8754", "19.0818", "11.0", "314.1", "0.2"]
        )!
        let att = XATTPacket(simulatorName: "Aerofly FS 4", fields: ["10.0", "1.0", "2.0"])!

        var context = FlightContext.empty
        context = context.merging(gps)
        context = context.merging(att)

        // Position fields from the earlier XGPS packet must survive an
        // unrelated XATT update.
        #expect(context.latitude == 19.0818)
        #expect(context.longitude == 72.8754)
    }

    @Test func preservesConnectionStatusAcrossMerges() {
        var context = FlightContext.empty
        context.connectionStatus = .listening

        let gps = XGPSPacket(
            simulatorName: "Aerofly FS 4",
            fields: ["72.8754", "19.0818", "11.0", "314.1", "0.2"]
        )!
        let merged = context.merging(gps)

        #expect(merged.connectionStatus == .listening)
    }
}
