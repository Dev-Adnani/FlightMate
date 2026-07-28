//
//  GeoBearing.swift
//  FlightMate
//
//  Pure initial-bearing (forward azimuth) math, used only for ground-track
//  estimation. Kept inside Core/FlightAnalysis rather than added to
//  Core/Airport/GeoDistance.swift, specifically to avoid touching any
//  file from a completed milestone.
//

import Foundation

/// Initial bearing (forward azimuth) calculations between WGS84
/// coordinates.
enum GeoBearing {
    /// Returns the initial bearing from `from` to `to`, in degrees true
    /// (0–360), using the standard forward-azimuth formula.
    ///
    /// Returns `nil` when `from == to` -- bearing is undefined at zero
    /// distance, so this deliberately never returns an arbitrary value.
    static func degreesTrue(from: GeoCoordinate, to: GeoCoordinate) -> Double? {
        guard from != to else { return nil }

        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let deltaLon = (to.longitude - from.longitude).radians

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearing = atan2(y, x).degrees

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
