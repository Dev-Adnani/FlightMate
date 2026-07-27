//
//  GeoCoordinate.swift
//  FlightMate
//
//  A plain WGS84 coordinate used by the reference data layer. Kept
//  independent from telemetry types so this layer has no dependency on
//  the telemetry/context engine.
//

import Foundation

/// A latitude/longitude pair in decimal degrees (WGS84).
struct GeoCoordinate: Equatable, Hashable {
    let latitude: Double
    let longitude: Double
}
