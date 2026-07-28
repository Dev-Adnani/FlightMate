//
//  CategoryPlaceholderAssetProvider.swift
//  FlightMate
//
//  Mid-priority provider: category illustration when a FlightMate-bundled
//  category image exists, otherwise the category's SF Symbol stand-in.
//  Always succeeds when `request.category` is non-nil.
//

import Foundation

/// Resolves a category-level placeholder for an aircraft preview.
struct CategoryPlaceholderAssetProvider: AircraftAssetProviding {
    let providerID = "flightmate.category.placeholder"

    private let imageLocator: BundleImageLooking

    init(imageLocator: BundleImageLooking = BundleImageLocator()) {
        self.imageLocator = imageLocator
    }

    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset? {
        guard let category = request.category else { return nil }

        if imageLocator.hasImage(named: category.assetResourceName) {
            return AircraftAsset(
                content: .bundleImage(resourceName: category.assetResourceName),
                source: .categoryPlaceholder,
                cacheKey: request.cacheKey
            )
        }

        return AircraftAsset(
            content: .systemSymbol(name: category.assetSystemImage),
            source: .categoryPlaceholder,
            cacheKey: request.cacheKey
        )
    }
}
