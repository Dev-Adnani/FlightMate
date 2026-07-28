//
//  AirportDomainResolving.swift
//  FlightMate
//
//  Protocol for resolving raw Aerofly airport/runway identifiers into
//  bundled reference data. See DomainResolutionService for the default
//  implementation, and ResolvedAirport for what a resolved result carries.
//

import Foundation

/// Resolves raw Aerofly airport/runway identifiers into bundled reference
/// data (`Airport`, `Runway`), plus country (currently always
/// unresolvable -- see `CountryResolving`).
protocol AirportDomainResolving {
    /// Looks up a single airport by its ICAO identifier. `nil` if unknown
    /// to the bundled reference data.
    func resolveAirport(icaoCode: String) -> Airport?

    /// Looks up a single runway at a given airport. `nil` if the airport
    /// is unknown, or (currently always the case -- see `Runway`) the
    /// bundled data has no runway-level detail at all.
    func resolveRunway(icaoCode: String, identifier: String) -> Runway?

    /// Resolves an `AeroflySession.RunwayReference` into a
    /// `ResolvedAirport`. Always returns a value -- see
    /// `ResolvedAirport.status` for whether resolution actually succeeded.
    func resolve(_ reference: AeroflySession.RunwayReference) -> ResolvedAirport
}
