//
//  AircraftAssetCache.swift
//  FlightMate
//
//  In-memory cache for resolved AircraftAssets. The protocol is deliberately
//  small so a future disk-backed implementation can conform without any
//  change to AircraftAssetManager.
//

import Foundation

/// Stores already-resolved `AircraftAsset` values keyed by
/// `AircraftAssetRequest.cacheKey`.
///
/// Caches the *resolution result* (which representation won), not decoded
/// bitmaps -- SwiftUI/`NSImage` already cache named bundle images, and
/// SF Symbols need no pixel cache. A future disk cache that stores raster
/// data can sit behind the same protocol by keying on the same strings.
protocol AircraftAssetCaching: AnyObject {
    func asset(forKey key: String) -> AircraftAsset?
    func store(_ asset: AircraftAsset, forKey key: String)
    func removeAll()
}

/// Default in-memory implementation. Bounded only by process lifetime --
/// aircraft codes are a tiny set (~44 stock + add-ons), so an unbounded
/// dictionary is fine for now. A future disk cache can wrap or replace
/// this without touching call sites.
final class InMemoryAircraftAssetCache: AircraftAssetCaching {
    private var storage: [String: AircraftAsset] = [:]

    func asset(forKey key: String) -> AircraftAsset? {
        storage[key]
    }

    func store(_ asset: AircraftAsset, forKey key: String) {
        storage[key] = asset
    }

    func removeAll() {
        storage.removeAll()
    }
}
