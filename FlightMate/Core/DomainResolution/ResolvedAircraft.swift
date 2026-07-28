//
//  ResolvedAircraft.swift
//  FlightMate
//
//  Composite domain object produced by resolving an AeroflySession's
//  AircraftSelection (raw aeroflyCode/liveryCode pair) into full reference
//  data, via DomainResolutionService.
//

import Foundation

/// The result of resolving one `AeroflySession.AircraftSelection` into
/// bundled reference data.
///
/// Always returned (never `nil`) from `AircraftDomainResolving.resolve(_:)`
/// -- whether resolution actually succeeded is answered by `status`, not by
/// object presence. `aircraft`/`livery` are only ever a real, bundled
/// domain object or `nil`; nothing here is ever fabricated.
struct ResolvedAircraft: Equatable {
    /// The raw Aerofly aircraft code that was resolved, e.g. "a320_neo".
    let aircraftCode: String

    /// The raw Aerofly livery code that was resolved, e.g. "lufthansa".
    /// May be an empty string if `main.mcf` had no paint scheme recorded.
    let liveryCode: String

    /// The matching bundled `Aircraft`, or `nil` if `aircraftCode` is
    /// unknown to the reference data.
    let aircraft: Aircraft?

    /// The matching bundled `AircraftLivery`, or `nil` if `liveryCode` is
    /// unknown for this aircraft (or `aircraft` itself is `nil`).
    let livery: AircraftLivery?

    /// Broad grouping derived from the resolved aircraft's tags. `nil`
    /// whenever `aircraft` is `nil` -- never guessed.
    ///
    /// Future capability flags (e.g. "supports checklist," "supports
    /// cockpit guide") belong here as additional **computed** properties,
    /// mirroring this one -- never as stored fields -- so they can be
    /// added later without changing this struct's initializer or any
    /// `DomainResolutionService` call site.
    var category: AircraftCategory? { aircraft?.category }

    /// Whether resolution actually succeeded -- see `DomainResolutionStatus`.
    /// `.unresolved` if `aircraftCode` itself didn't match anything;
    /// `.partial` if the aircraft resolved but a non-empty `liveryCode`
    /// didn't; `.resolved` otherwise (including when `liveryCode` was
    /// empty to begin with -- there was nothing to look up).
    var status: DomainResolutionStatus {
        guard aircraft != nil else { return .unresolved }
        if livery == nil && !liveryCode.isEmpty {
            return .partial
        }
        return .resolved
    }
}
