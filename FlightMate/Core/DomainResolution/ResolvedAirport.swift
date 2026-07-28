//
//  ResolvedAirport.swift
//  FlightMate
//
//  Composite domain object produced by resolving an AeroflySession's
//  RunwayReference (airport ICAO + optional runway identifier) into full
//  reference data, via DomainResolutionService.
//

import Foundation

/// The result of resolving one `AeroflySession.RunwayReference` into
/// bundled reference data.
///
/// Always returned (never `nil`) from `AirportDomainResolving.resolve(_:)`
/// -- whether resolution actually succeeded is answered by `status`, not by
/// object presence.
struct ResolvedAirport: Equatable {
    /// The raw ICAO code that was resolved, e.g. "VABB".
    let icaoCode: String

    /// The raw runway identifier that was resolved, if any, e.g. "27".
    let runwayIdentifier: String?

    /// The matching bundled `Airport`, or `nil` if `icaoCode` is unknown to
    /// the reference data.
    let airport: Airport?

    /// The matching `Runway` at `airport`, or `nil` if `airport` is `nil`,
    /// `runwayIdentifier` is `nil`, or (currently always the case -- see
    /// `Runway`) the bundled data has no runway-level detail at all. Not a
    /// bug: `Airport.runways` is always empty until a runway dataset is
    /// bundled -- see `DomainResolutionReport` for how this is surfaced as
    /// an informational diagnostic rather than an error.
    let runway: Runway?

    /// The airport's country, or `nil` -- always `nil` today, since no
    /// country dataset is bundled (see `CountryResolving`). Never inferred
    /// from the ICAO prefix.
    let country: String?

    /// Whether the airport itself resolved -- see `DomainResolutionStatus`.
    /// A missing `runway`/`country` never downgrades this to `.partial`:
    /// those are permanent, known dataset gaps, not per-lookup failures.
    var status: DomainResolutionStatus {
        airport != nil ? .resolved : .unresolved
    }
}
