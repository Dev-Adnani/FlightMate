//
//  CountryResolving.swift
//  FlightMate
//
//  Extensibility seam for country resolution. No country dataset is
//  bundled today, so DomainResolutionService always resolves country as
//  nil -- this protocol exists purely so a future implementation can be
//  swapped in without changing ResolvedAirport's shape or any call site.
//

import Foundation

/// Resolves an airport's country from its ICAO code.
protocol CountryResolving {
    /// - Returns: The country name/code for `icaoCode`, or `nil` if
    ///   unknown/unavailable.
    func resolveCountry(forICAO icaoCode: String) -> String?
}

/// No country dataset is bundled yet (see `PROJECT_CONTEXT.md`). Always
/// returns `nil` rather than inferring from ICAO region prefixes --
/// deliberately rejected even though ICAO prefixes are standardized,
/// because that would still be a separate reference dataset outside this
/// project's current bundled sources.
///
/// Swap this implementation for a real one (backed by a dedicated,
/// versioned country dataset) once one is added -- `ResolvedAirport`'s
/// shape and every `DomainResolutionService` call site stay unchanged.
struct UnavailableCountryResolver: CountryResolving {
    func resolveCountry(forICAO icaoCode: String) -> String? { nil }
}
