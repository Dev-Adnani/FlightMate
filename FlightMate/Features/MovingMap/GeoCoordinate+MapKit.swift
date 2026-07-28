//
//  GeoCoordinate+MapKit.swift
//  FlightMate
//
//  The Moving Map feature's one and only bridge from FlightMate's plain
//  `GeoCoordinate` domain type to MapKit/CoreLocation. Deliberately kept
//  here, not on `GeoCoordinate` itself -- see `GeoCoordinate`'s own
//  documentation on staying independent of any one consumer.
//

import CoreLocation

extension GeoCoordinate {
    /// This coordinate, expressed as the type MapKit's APIs expect.
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
