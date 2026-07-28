//
//  AircraftAssetRequest.swift
//  FlightMate
//
//  The input to AircraftAssetManager: everything a provider needs to decide
//  which preview (if any) it can supply. Views never build filesystem paths
//  themselves -- they pass codes/category and receive a resolved asset.
//

import Foundation

/// Preferred visual size for an aircraft preview. Providers may use this to
/// pick between a full preview and a smaller thumbnail when both exist in
/// a future asset pack; today's providers ignore it and return the same
/// representation for either size.
enum AircraftAssetSize: String, Equatable, Hashable {
    case regular
    case small
}

/// Everything needed to resolve one aircraft (and optionally livery) preview.
struct AircraftAssetRequest: Equatable, Hashable {
    /// Aerofly aircraft code, e.g. `"a320_neo"`. Empty only for the
    /// "no aircraft loaded" case -- providers treat that as unresolvable
    /// and fall through to the SF Symbol fallback.
    let aircraftCode: String

    /// Aerofly livery code, e.g. `"lufthansa"`. `nil` or empty means
    /// "aircraft only" -- providers must not invent a livery.
    let liveryCode: String?

    /// Broad grouping, when known. Used by the category-placeholder
    /// provider; ignored by the per-aircraft bundled provider.
    let category: AircraftCategory?

    let preferredSize: AircraftAssetSize

    /// Stable cache key for this request. Shared by the in-memory cache
    /// today and any future disk cache.
    var cacheKey: String {
        let livery = (liveryCode?.isEmpty == false) ? liveryCode! : "-"
        let categoryKey = category?.rawValue ?? "-"
        return "\(aircraftCode)|\(livery)|\(categoryKey)|\(preferredSize.rawValue)"
    }

    init(
        aircraftCode: String,
        liveryCode: String? = nil,
        category: AircraftCategory? = nil,
        preferredSize: AircraftAssetSize = .regular
    ) {
        self.aircraftCode = aircraftCode
        self.liveryCode = liveryCode.flatMap { $0.isEmpty ? nil : $0 }
        self.category = category
        self.preferredSize = preferredSize
    }

    /// Builds a request from a resolved aircraft -- the usual call site
    /// for Dashboard / Aircraft Browser / AI context.
    static func from(_ resolved: ResolvedAircraft, preferredSize: AircraftAssetSize = .regular) -> AircraftAssetRequest {
        AircraftAssetRequest(
            aircraftCode: resolved.aircraftCode,
            liveryCode: resolved.liveryCode,
            category: resolved.category,
            preferredSize: preferredSize
        )
    }
}
