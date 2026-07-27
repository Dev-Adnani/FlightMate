//
//  XATTPacketTests.swift
//  FlightMateTests
//

import Testing
@testable import FlightMate

struct XATTPacketTests {

    @Test func decodesExamplePacket() {
        let fields: [Substring] = ["314.1", "-0.23", "0.29"]
        let packet = XATTPacket(simulatorName: "Aerofly FS 4", fields: fields)

        #expect(packet != nil)
        #expect(packet?.simulatorName == "Aerofly FS 4")
        #expect(packet?.headingDegreesTrue == 314.1)
        #expect(packet?.pitchDegrees == -0.23)
        #expect(packet?.rollDegrees == 0.29)
    }

    @Test func rejectsTooFewFields() {
        let fields: [Substring] = ["314.1", "-0.23"]
        #expect(XATTPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func rejectsTooManyFields() {
        let fields: [Substring] = ["314.1", "-0.23", "0.29", "extra"]
        #expect(XATTPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func rejectsNonNumericField() {
        let fields: [Substring] = ["314.1", "not-a-number", "0.29"]
        #expect(XATTPacket(simulatorName: "Aerofly FS 4", fields: fields) == nil)
    }

    @Test func wirePrefixIsXATT() {
        #expect(XATTPacket.wirePrefix == "XATT")
    }
}
