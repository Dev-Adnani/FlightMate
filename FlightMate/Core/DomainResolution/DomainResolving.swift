//
//  DomainResolving.swift
//  FlightMate
//
//  Combined facade protocol for the Domain Resolution layer. Kept separate
//  from AircraftDomainResolving/AirportDomainResolving so either half can
//  be depended on independently by a future caller that only needs one.
//

import Foundation

/// Resolves an entire `AeroflySession` (aircraft, livery, departure,
/// destination) into a `ResolvedSession`, alongside a developer-facing
/// `DomainResolutionReport` describing exactly what did and didn't
/// resolve.
protocol DomainResolving: AircraftDomainResolving, AirportDomainResolving {
    func resolve(_ session: AeroflySession) -> (resolved: ResolvedSession, report: DomainResolutionReport)
}
