//
//  ResolvedSession.swift
//  FlightMate
//
//  The fully resolved view of an AeroflySession -- every raw Aerofly code
//  (aircraft, livery, departure, destination) turned into rich domain
//  objects. Produced by DomainResolutionService.resolve(_:).
//
//  Named "ResolvedSession," not "ResolvedAeroflySession": it represents the
//  resolved current session conceptually, not simulator-specific logic. The
//  resolver's *input* stays typed as AeroflySession (the only session
//  source that exists today); only this output type's name is
//  simulator-agnostic, so it wouldn't need renaming if a second simulator
//  were ever supported.
//

import Foundation

/// A complete, resolved snapshot of an `AeroflySession`: every raw Aerofly
/// identifier resolved into bundled reference data (or left `nil`, never
/// fabricated).
struct ResolvedSession: Equatable {
    /// `nil` only if the session itself had no aircraft selection at all
    /// (`AeroflySession.aircraft == nil`). Once there was a selection to
    /// resolve, this is always present -- see `ResolvedAircraft.status`
    /// for whether the codes it holds actually matched anything.
    let aircraft: ResolvedAircraft?

    /// `nil` only if the session itself had no departure reference at all.
    /// Should not happen in practice -- Aerofly always records a spawn
    /// airport/runway, even without a flight plan.
    let departure: ResolvedAirport?

    /// `nil` if the session has no destination (no flight plan set) --
    /// never fabricated. Once there was a destination reference, this is
    /// always present -- see `ResolvedAirport.status`.
    let destination: ResolvedAirport?
}
