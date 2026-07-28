//
//  GeoTrailPoint.swift
//  FlightMate
//
//  One sampled position in a recorded geographic trail. See
//  `MapTrailService` for how these are produced.
//

import Foundation

/// A single timestamped position sample.
///
/// Deliberately independent of MapKit/CoreLocation -- this is a plain
/// domain value, consumed today by the Moving Map's breadcrumb trail, and
/// designed to be reused unchanged by future consumers (Replay, GPX
/// export, a standalone Flight Recorder) without pulling any UI
/// framework into `Core`.
struct GeoTrailPoint: Equatable {
    let coordinate: GeoCoordinate
    let timestamp: Date
}
