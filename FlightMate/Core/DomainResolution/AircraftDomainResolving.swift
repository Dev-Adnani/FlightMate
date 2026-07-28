//
//  AircraftDomainResolving.swift
//  FlightMate
//
//  Protocol for resolving raw Aerofly aircraft/livery codes into bundled
//  reference data. See DomainResolutionService for the default
//  implementation, and ResolvedAircraft for what a resolved result carries.
//

import Foundation

/// Resolves raw Aerofly aircraft/livery identifiers into bundled reference
/// data (`Aircraft`, `AircraftLivery`).
protocol AircraftDomainResolving {
    /// Looks up a single aircraft by its Aerofly identifier (e.g.
    /// "a320_neo"). `nil` if unknown to the bundled reference data.
    func resolveAircraft(aeroflyCode: String) -> Aircraft?

    /// Looks up a single livery by its Aerofly identifier, scoped to a
    /// specific aircraft (livery codes aren't globally unique). `nil` if
    /// either the aircraft or the livery is unknown.
    func resolveLivery(aeroflyCode: String, forAircraft aircraftAeroflyCode: String) -> AircraftLivery?

    /// Resolves an `AeroflySession.AircraftSelection` into a
    /// `ResolvedAircraft`. Always returns a value -- see
    /// `ResolvedAircraft.status` for whether resolution actually
    /// succeeded.
    func resolve(_ selection: AeroflySession.AircraftSelection) -> ResolvedAircraft
}
