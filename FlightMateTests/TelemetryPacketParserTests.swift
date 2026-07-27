//
//  TelemetryPacketParserTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct TelemetryPacketParserTests {

    // MARK: - XGPS

    @Test func parsesXGPSExampleFromString() {
        let result = TelemetryPacketParser.parse("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2")
        let gps = result as? XGPSPacket

        #expect(gps != nil)
        #expect(gps?.simulatorName == "Aerofly FS 4")
        #expect(gps?.longitude == 72.8754)
        #expect(gps?.latitude == 19.0818)
        #expect(gps?.altitudeMeters == 11.0)
        #expect(gps?.trackDegreesTrue == 314.1)
        #expect(gps?.groundSpeedMetersPerSecond == 0.2)
    }

    @Test func parsesXGPSExampleFromRawUTF8Data() {
        let data = Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8)
        let result = TelemetryPacketParser.parse(data)
        #expect((result as? XGPSPacket) != nil)
    }

    // MARK: - XATT

    @Test func parsesXATTExampleFromString() {
        let result = TelemetryPacketParser.parse("XATTAerofly FS 4,314.1,-0.23,0.29")
        let att = result as? XATTPacket

        #expect(att != nil)
        #expect(att?.simulatorName == "Aerofly FS 4")
        #expect(att?.headingDegreesTrue == 314.1)
        #expect(att?.pitchDegrees == -0.23)
        #expect(att?.rollDegrees == 0.29)
    }

    @Test func parsesXATTExampleFromRawUTF8Data() {
        let data = Data("XATTAerofly FS 4,314.1,-0.23,0.29".utf8)
        let result = TelemetryPacketParser.parse(data)
        #expect((result as? XATTPacket) != nil)
    }

    // MARK: - Unknown / malformed packets are ignored, not thrown

    @Test func ignoresUnknownPacketType() {
        let result = TelemetryPacketParser.parse("XTRAFFICAerofly FS 4,1,2,3")
        #expect(result == nil)
    }

    @Test func ignoresEmptyPacket() {
        let result = TelemetryPacketParser.parse("")
        #expect(result == nil)
    }

    @Test func ignoresKnownPrefixWithWrongFieldCount() {
        let result = TelemetryPacketParser.parse("XGPSAerofly FS 4,72.8754")
        #expect(result == nil)
    }

    @Test func ignoresKnownPrefixWithNonNumericField() {
        let result = TelemetryPacketParser.parse("XATTAerofly FS 4,not-a-number,-0.23,0.29")
        #expect(result == nil)
    }

    @Test func ignoresNonUTF8Data() {
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD])
        let result = TelemetryPacketParser.parse(invalidUTF8)
        #expect(result == nil)
    }

    // MARK: - Trims incidental whitespace/newlines

    @Test func trimsTrailingWhitespaceAndNewlines() {
        let result = TelemetryPacketParser.parse("XATTAerofly FS 4,314.1,-0.23,0.29\r\n")
        #expect((result as? XATTPacket) != nil)
    }
}
