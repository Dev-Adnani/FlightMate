//
//  XATTPacket.swift
//  FlightMate
//
//  Strongly typed model for the "XATT" telemetry packet (aircraft attitude).
//

import Foundation

/// A decoded `XATT` packet: aircraft attitude.
///
/// ## Wire format
/// ```
/// XATT<simulatorName>,<headingDegreesTrue>,<pitchDegrees>,<rollDegrees>
/// ```
///
/// Example:
/// ```
/// XATTAerofly FS 4,314.1,-0.23,0.29
/// ```
struct XATTPacket: TelemetryPacket, Equatable {
    static let wirePrefix = "XATT"

    /// Identifier of the simulator/app that sent this packet, e.g. `"Aerofly FS 4"`.
    let simulatorName: String

    /// True heading, in degrees (0–360).
    let headingDegreesTrue: Double

    /// Pitch, in degrees. Positive is nose up.
    let pitchDegrees: Double

    /// Roll, in degrees. Positive is right wing down.
    let rollDegrees: Double

    init?(simulatorName: String, fields: [Substring]) {
        guard
            fields.count == 3,
            let headingDegreesTrue = Double(fields[0]),
            let pitchDegrees = Double(fields[1]),
            let rollDegrees = Double(fields[2])
        else {
            return nil
        }

        self.simulatorName = simulatorName
        self.headingDegreesTrue = headingDegreesTrue
        self.pitchDegrees = pitchDegrees
        self.rollDegrees = rollDegrees
    }
}
