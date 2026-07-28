//
//  SystemSymbolAssetProvider.swift
//  FlightMate
//
//  Final fallback provider: always returns a generic SF Symbol so the
//  manager's resolve(_:) is total -- every request produces an asset.
//

import Foundation

/// Always-succeeding SF Symbol fallback.
struct SystemSymbolAssetProvider: AircraftAssetProviding {
    let providerID = "flightmate.systemSymbol"

    /// Default symbol used when nothing else in the chain could answer.
    static let fallbackSystemImage = "airplane.circle.fill"

    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset? {
        AircraftAsset(
            content: .systemSymbol(name: Self.fallbackSystemImage),
            source: .systemSymbol,
            cacheKey: request.cacheKey
        )
    }
}
