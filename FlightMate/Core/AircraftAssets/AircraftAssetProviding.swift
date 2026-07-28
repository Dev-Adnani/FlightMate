//
//  AircraftAssetProviding.swift
//  FlightMate
//
//  Provider seam for AircraftAssetManager. Each provider answers one tier
//  of the fallback chain (bundled aircraft art, category placeholder, SF
//  Symbol, and -- later -- user asset packs / official IPACS support).
//  The manager walks providers in priority order; the first non-nil win.
//

import Foundation

/// One source of aircraft preview images.
///
/// Providers must be pure with respect to the filesystem beyond their own
/// declared root (bundle, user asset-pack directory, etc.) and must never
/// reach into Aerofly's proprietary `.ttx` textures -- see the Aircraft
/// Asset Manager milestone research notes. Returning `nil` means "I can't
/// satisfy this request; try the next provider."
protocol AircraftAssetProviding {
    /// Stable identity for logging / Developer Tools. Not shown to users.
    var providerID: String { get }

    /// - Returns: A resolved asset, or `nil` to fall through to the next
    ///   provider in the manager's chain.
    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset?
}
