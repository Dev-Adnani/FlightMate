//
//  MovingMapAirportAnnotation.swift
//  FlightMate
//
//  One airport pin the Moving Map shows -- departure, destination, or
//  nearest. Kept as its own small type so MovingMapViewModel/View stay
//  readable.
//

import CoreLocation

/// One airport annotation rendered on the Moving Map.
struct MovingMapAirportAnnotation: Identifiable, Equatable {
    /// Why this airport is shown. An airport matching more than one role
    /// (e.g. the nearest airport is also the destination) is only ever
    /// represented once -- see `MovingMapViewModel`'s role-priority
    /// dedup logic -- so `role` here is its single, highest-priority
    /// reason for appearing.
    enum Role: Equatable {
        case departure
        case destination
        case nearest
    }

    /// The airport's ICAO code -- stable, unique identity for SwiftUI's
    /// `ForEach`, so re-renders never recreate annotations that haven't
    /// actually changed.
    let id: String
    let role: Role
    let airport: Airport

    var coordinate: CLLocationCoordinate2D { airport.coordinate.clLocationCoordinate }
}
