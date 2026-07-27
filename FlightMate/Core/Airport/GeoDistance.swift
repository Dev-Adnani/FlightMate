//
//  GeoDistance.swift
//  FlightMate
//
//  Pure great-circle distance math, isolated from AirportService so it can
//  be unit tested independently of any bundled data.
//

import Foundation

/// Great-circle distance calculations between WGS84 coordinates.
enum GeoDistance {
    /// Mean radius of the Earth, in nautical miles.
    private static let earthRadiusNauticalMiles = 3_440.065

    /// Returns the great-circle distance between two coordinates, in nautical
    /// miles, using the haversine formula.
    static func nauticalMiles(from: GeoCoordinate, to: GeoCoordinate) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let deltaLat = (to.latitude - from.latitude).radians
        let deltaLon = (to.longitude - from.longitude).radians

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())

        return earthRadiusNauticalMiles * c
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
}
