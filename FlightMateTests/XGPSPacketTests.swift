//
//  XGPSPacketTests.swift
//  FlightMateTests
//

import Testing
@testable import FlightMate

struct XGPSPacketTests {

    @Test func decodesExamplePacket() {
        let fields: [Substring] = ["72.8754", "19.0818", "11.0", "314.1", "0.2"]
        let packet = XGPSPacket(simulatorName: "Aerofly FS 4", fields: fields)

        #expect(packet != nil)
        #expect(packet?.simulatorName == "Aerofly FS 4")
        #expect(packet?.longitude == 72.8754)
        #expect(packet?.latitude == 19.0818)
        #expect(packet?.altitudeMeters == 11.0)
        #expect(packet?.trackDegreesTrue == 314.1)
        #expect(packet?.groundSpeedMetersPerSecond == 0.2)
    }

    @Test func rejectsTooFewFields() {
        let fields: [Substring] = ["72.8754", "19.0818"]
        #expect(XGPSPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func rejectsTooManyFields() {
        let fields: [Substring] = ["72.8754", "19.0818", "11.0", "314.1", "0.2", "extra"]
        #expect(XGPSPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func rejectsNonNumericField() {
        let fields: [Substring] = ["not-a-number", "19.0818", "11.0", "314.1", "0.2"]
        #expect(XGPSPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func wirePrefixIsXGPS() {
        #expect(XGPSPacket.wirePrefix == "XGPS")
    }
}
