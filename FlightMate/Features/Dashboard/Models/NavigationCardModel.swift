//
//  NavigationCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for NavigationCard, derived from
//  FlightAnalysis (departure/destination/nearest) plus FlightContext
//  (current heading -- FlightAnalysis deliberately excludes raw telemetry,
//  see its own documentation). NavigationCard never touches FlightAnalysis
//  or FlightContext directly -- only this model.
//

import Foundation

/// Everything `NavigationCard` needs to render, and nothing else.
struct NavigationCardModel: Equatable {
    let departure: AirportCardModel
    let destination: AirportCardModel
    let nearest: AirportCardModel
    let headingDegrees: Double?

    static let empty = NavigationCardModel(
        departure: .from(role: .departure, resolved: nil),
        destination: .from(role: .destination, resolved: nil),
        nearest: .from(role: .nearest, resolved: nil),
        headingDegrees: nil
    )

    static func from(context: FlightContext, analysis: FlightAnalysis) -> NavigationCardModel {
        NavigationCardModel(
            departure: .from(role: .departure, resolved: analysis.resolvedDeparture),
            destination: .from(role: .destination, resolved: analysis.resolvedDestination),
            nearest: .from(
                role: .nearest,
                resolved: analysis.nearestAirport,
                distanceNauticalMiles: analysis.distanceToNearestAirportNauticalMiles
            ),
            headingDegrees: context.headingDegreesTrue
        )
    }
}
