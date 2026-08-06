//
//  AeroflyPositionConverter.swift
//  FlightMate
//
//  Converts main.mcf's ECEF-style flight position vector into a geodetic
//  (lon/lat) coordinate.
//

import Foundation

/// Converts `tmsettings_flight.position` (an ECEF-style `[x, y, z]` vector,
/// in meters) into a `GeoCoordinate`.
///
/// This is a community-reverse-engineered formula, not an official Aerofly
/// API — see
/// https://www.aerofly.com/community/forum/index.php?thread/19105-custom-missions-converting-coordinates/.
/// It's ported here (reimplemented in Swift, not copied) from
/// `fboes/aerofly-missions`' `LonLat.fromMainMcf`.
///
/// Deliberately does **not** derive altitude: this formula only recovers
/// longitude/latitude from the vector. Altitude from `main.mcf` is treated
/// as unavailable — see `AeroflySession`'s documentation on why UDP
/// telemetry, not this conversion, is the authoritative altitude source.
enum AeroflyPositionConverter {
    /// WGS84 flattening.
    private static let flattening = 1.0 / 298.257223563
    private static let eccentricitySquared = 2 * flattening - flattening * flattening

    /// - Parameter position: the raw `[x, y, z]` vector from
    ///   `tmsettings_flight.position`.
    /// - Returns: The equivalent lon/lat coordinate, or `nil` if `position`
    ///   doesn't have exactly 3 components.
    static func coordinate(fromPosition position: [Double]) -> GeoCoordinate? {
        guard position.count == 3 else { return nil }
        let x = position[0]
        let y = position[1]
        let z = position[2]

        let lambda: Double
        if x > 0 {
            lambda = y < 0 ? (2 * Double.pi + atan(y / x)) : atan(y / x)
        } else if x < 0 {
            lambda = Double.pi + atan(y / x)
        } else if y > 0 {
            lambda = 0.5 * Double.pi
        } else {
            lambda = 1.5 * Double.pi
        }

        let rho = (x * x + y * y).squareRoot()
        let phi = atan(z / ((1.0 - eccentricitySquared) * rho))

        let longitude = lambda * 180 / Double.pi
        let latitude = phi * 180 / Double.pi
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Inverse of `coordinate(fromPosition:)` — WGS84 geodetic to ECEF meters.
    /// Ported from Missionsgerät `MainMcfExport.convertCoordinates`.
    static func position(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double = 0
    ) -> [Double] {
        let a = 6_378_137.0
        let f = flattening
        let e2 = f * (2 - f)
        let lat = latitude * Double.pi / 180
        let lon = longitude * Double.pi / 180
        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let n = a / (1 - e2 * sinLat * sinLat).squareRoot()
        let x = (n + altitudeMeters) * cosLat * cos(lon)
        let y = (n + altitudeMeters) * cosLat * sin(lon)
        let z = (n * (1 - e2) + altitudeMeters) * sinLat
        return [x, y, z]
    }
}
