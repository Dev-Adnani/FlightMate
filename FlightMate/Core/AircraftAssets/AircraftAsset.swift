//
//  AircraftAsset.swift
//  FlightMate
//
//  The resolved preview returned by AircraftAssetManager. Deliberately
//  opaque about *where* the image came from beyond a coarse `source`
//  enum -- Views never branch on provider identity.
//

import Foundation

/// Coarse answer to "which tier of the fallback chain produced this?"
/// Useful for debugging / Developer Tools; Views should not switch on it
/// for layout decisions.
enum AircraftAssetSource: String, Equatable {
    /// A FlightMate-bundled per-aircraft (or per-livery) image.
    case bundledAircraft
    /// A FlightMate-bundled category illustration, or the category's
    /// SF Symbol stand-in when no illustration is shipped yet.
    case categoryPlaceholder
    /// The final SF Symbol fallback -- always available.
    case systemSymbol
}

/// How the preview should be rendered in SwiftUI. Kept as named bundle /
/// system-symbol references (not decoded bitmaps) so Equatable stays
/// trivial and AppKit/`NSImage` never leaks into the Feature layer.
///
/// Future providers that load from disk or the network can extend this
/// with additional cases (e.g. a file URL) without changing
/// `AircraftAssetManager`'s public `resolve` signature -- only the
/// rendering helper that maps `AircraftAssetContent` → `Image` grows.
enum AircraftAssetContent: Equatable {
    /// An image resource name present in the app bundle (no extension).
    /// Loaded via `Image(_ name:)` / `NSImage(named:)`.
    case bundleImage(resourceName: String)

    /// An SF Symbol name, always available offline.
    case systemSymbol(name: String)
}

/// One resolved aircraft preview, ready for a View to render.
struct AircraftAsset: Equatable {
    let content: AircraftAssetContent
    let source: AircraftAssetSource

    /// The cache key of the request that produced this asset -- carried so
    /// a future disk cache can store/retrieve without recomputing keys.
    let cacheKey: String
}
