//
//  BundledAircraftAssetProvider.swift
//  FlightMate
//
//  Highest-priority provider: FlightMate-owned per-aircraft (and, when
//  present, per-livery) preview images shipped inside the app bundle.
//  Returns nil when no matching resource exists so the category / SF
//  Symbol providers can take over -- never invents artwork.
//

import Foundation

/// Resolves FlightMate-bundled aircraft preview images.
///
/// ## Naming convention
/// Documented in `Resources/Aircraft/Assets/Assets.md`:
/// - Aircraft: `{aeroflyCode}` (e.g. `a320_neo.png`)
/// - Livery (optional, preferred when present): `{aeroflyCode}-{liveryCode}`
///   (e.g. `a320_neo-lufthansa.png`)
///
/// No images are required to ship for this provider to be correct -- an
/// empty Assets folder simply means every request falls through.
struct BundledAircraftAssetProvider: AircraftAssetProviding {
    let providerID = "flightmate.bundled.aircraft"

    private let imageLocator: BundleImageLooking

    init(imageLocator: BundleImageLooking = BundleImageLocator()) {
        self.imageLocator = imageLocator
    }

    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset? {
        guard !request.aircraftCode.isEmpty else { return nil }

        if let livery = request.liveryCode {
            let liveryResource = "\(request.aircraftCode)-\(livery)"
            if imageLocator.hasImage(named: liveryResource) {
                return AircraftAsset(
                    content: .bundleImage(resourceName: liveryResource),
                    source: .bundledAircraft,
                    cacheKey: request.cacheKey
                )
            }
        }

        if imageLocator.hasImage(named: request.aircraftCode) {
            return AircraftAsset(
                content: .bundleImage(resourceName: request.aircraftCode),
                source: .bundledAircraft,
                cacheKey: request.cacheKey
            )
        }

        return nil
    }
}
