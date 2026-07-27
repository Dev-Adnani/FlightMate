//
//  XGPSPacket.swift
//  FlightMate
//
//  Strongly typed model for the "XGPS" telemetry packet (aircraft position).
//

import Foundation

/// A decoded `XGPS` packet: aircraft position and ground track.
///
/// ## Wire format
/// ```
/// XGPS<simulatorName>,<longitude>,<latitude>,<altitudeMeters>,<trackDegreesTrue>,<groundSpeedMetersPerSecond>
/// ```
///
/// Example:
/// ```
/// XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2
/// ```
struct XGPSPacket: TelemetryPacket, Equatable {
    static let wirePrefix = "XGPS"

    /// Identifier of the simulator/app that sent this packet, e.g. `"Aerofly FS 4"`.
    let simulatorName: String

    /// Longitude, in degrees. Positive is east.
    let longitude: Double

    /// Latitude, in degrees. Positive is north.
    let latitude: Double

    /// Altitude above mean sea level, in meters.
    let altitudeMeters: Double

    /// Ground track, in degrees true (0–360).
    let trackDegreesTrue: Double

    /// Ground speed, in meters per second.
    let groundSpeedMetersPerSecond: Double

    init?(simulatorName: String, fields: [Substring]) {
        guard
            fields.count == 5,
            let longitude = Double(fields[0]),
            let latitude = Double(fields[1]),
            let altitudeMeters = Double(fields[2]),
            let trackDegreesTrue = Double(fields[3]),
            let groundSpeedMetersPerSecond = Double(fields[4])
        else {
            return nil
        }

        self.simulatorName = simulatorName
        self.longitude = longitude
        self.latitude = latitude
        self.altitudeMeters = altitudeMeters
        self.trackDegreesTrue = trackDegreesTrue
        self.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
    }
}
