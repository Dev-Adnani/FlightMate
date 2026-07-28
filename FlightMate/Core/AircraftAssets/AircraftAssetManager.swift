//
//  AircraftAssetManager.swift
//  FlightMate
//
//  Resolves aircraft (and, later, livery) preview images through a
//  prioritized provider chain. Views never access the filesystem, never
//  hardcode image names, and never know which provider won -- they only
//  ever receive an AircraftAsset.
//
//  Intentionally does NOT include an Aerofly .ttx provider: IPACS's texture
//  format is one-way by design, and FlightMate will not reverse-engineer
//  or redistribute copyrighted Aerofly artwork. Future providers (user
//  asset packs, licensed art, official IPACS support) plug into the same
//  AircraftAssetProviding seam without changing this type's public API.
//

import Foundation

/// Resolves aircraft preview images for the rest of the app.
protocol AircraftAssetManaging {
    /// Walks the provider chain and returns the best available preview.
    /// Always succeeds -- the final SF Symbol provider is total.
    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset

    /// Convenience for the common `ResolvedAircraft` call site.
    func resolve(aircraft: ResolvedAircraft, preferredSize: AircraftAssetSize) -> AircraftAsset

    /// Drops the in-memory resolution cache. Useful after a future
    /// user-installed asset pack is added/removed at runtime.
    func clearCache()
}

extension AircraftAssetManaging {
    func resolve(aircraft: ResolvedAircraft, preferredSize: AircraftAssetSize = .regular) -> AircraftAsset {
        resolve(.from(aircraft, preferredSize: preferredSize))
    }
}

/// Default `AircraftAssetManaging` implementation.
///
/// ## Dependency injection
/// Not a singleton. Providers and cache are injected so tests can supply
/// fakes, and so a future milestone can insert a user-asset-pack provider
/// ahead of the bundled one without redesigning call sites.
///
/// ## Default provider chain (highest priority first)
/// 1. `BundledAircraftAssetProvider` -- per-aircraft / per-livery PNG/WebP
/// 2. `CategoryPlaceholderAssetProvider` -- category illustration or
///    category SF Symbol
/// 3. `SystemSymbolAssetProvider` -- generic SF Symbol (always succeeds)
final class AircraftAssetManager: AircraftAssetManaging {
    private let providers: [AircraftAssetProviding]
    private let cache: AircraftAssetCaching

    /// - Parameters:
    ///   - providers: Ordered fallback chain. Defaults to the FlightMate-
    ///     owned chain documented above. Pass a custom array to insert
    ///     future providers (user packs, official IPACS, …) without
    ///     changing this type.
    ///   - cache: Resolution-result cache. Defaults to an in-memory store.
    init(
        providers: [AircraftAssetProviding] = AircraftAssetManager.defaultProviders,
        cache: AircraftAssetCaching = InMemoryAircraftAssetCache()
    ) {
        self.providers = providers
        self.cache = cache
    }

    /// The shipping provider chain -- FlightMate-owned assets only.
    static var defaultProviders: [AircraftAssetProviding] {
        [
            BundledAircraftAssetProvider(),
            CategoryPlaceholderAssetProvider(),
            SystemSymbolAssetProvider()
        ]
    }

    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset {
        if let cached = cache.asset(forKey: request.cacheKey) {
            return cached
        }

        for provider in providers {
            if let asset = provider.resolve(request) {
                cache.store(asset, forKey: request.cacheKey)
                return asset
            }
        }

        // Defense in depth: defaultProviders always ends with a total
        // SystemSymbolAssetProvider. This branch only fires if a caller
        // constructed the manager with an empty/broken provider list.
        let fallback = AircraftAsset(
            content: .systemSymbol(name: SystemSymbolAssetProvider.fallbackSystemImage),
            source: .systemSymbol,
            cacheKey: request.cacheKey
        )
        cache.store(fallback, forKey: request.cacheKey)
        return fallback
    }

    func clearCache() {
        cache.removeAll()
    }
}
