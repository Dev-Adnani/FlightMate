//
//  AircraftAssetManagerTests.swift
//  FlightMateTests
//
//  Verifies the provider-chain fallback order, caching, and that the
//  manager never invents artwork when bundle images are absent.
//

import Foundation
import Testing
@testable import FlightMate

private final class FakeBundleImageLocator: BundleImageLooking {
    var availableNames: Set<String>

    init(availableNames: Set<String> = []) {
        self.availableNames = availableNames
    }

    func hasImage(named resourceName: String) -> Bool {
        availableNames.contains(resourceName)
    }
}

private final class CountingProvider: AircraftAssetProviding {
    let providerID: String
    let asset: AircraftAsset?
    private(set) var resolveCount = 0

    init(providerID: String, asset: AircraftAsset?) {
        self.providerID = providerID
        self.asset = asset
    }

    func resolve(_ request: AircraftAssetRequest) -> AircraftAsset? {
        resolveCount += 1
        return asset.map {
            AircraftAsset(content: $0.content, source: $0.source, cacheKey: request.cacheKey)
        }
    }
}

@Suite("AircraftAssetManager")
struct AircraftAssetManagerTests {

    @Test func bundledAircraftImageWinsOverCategoryAndSymbol() {
        let locator = FakeBundleImageLocator(availableNames: ["a320_neo", "category-airliner"])
        let manager = AircraftAssetManager(providers: [
            BundledAircraftAssetProvider(imageLocator: locator),
            CategoryPlaceholderAssetProvider(imageLocator: locator),
            SystemSymbolAssetProvider()
        ])

        let asset = manager.resolve(
            AircraftAssetRequest(aircraftCode: "a320_neo", category: .airliner)
        )

        #expect(asset.source == .bundledAircraft)
        #expect(asset.content == .bundleImage(resourceName: "a320_neo"))
    }

    @Test func bundledLiveryImageIsPreferredOverAircraftImage() {
        let locator = FakeBundleImageLocator(availableNames: ["a320_neo", "a320_neo-lufthansa"])
        let manager = AircraftAssetManager(providers: [
            BundledAircraftAssetProvider(imageLocator: locator),
            SystemSymbolAssetProvider()
        ])

        let asset = manager.resolve(
            AircraftAssetRequest(aircraftCode: "a320_neo", liveryCode: "lufthansa", category: .airliner)
        )

        #expect(asset.content == .bundleImage(resourceName: "a320_neo-lufthansa"))
        #expect(asset.source == .bundledAircraft)
    }

    @Test func categoryIllustrationIsUsedWhenNoAircraftImageExists() {
        let locator = FakeBundleImageLocator(availableNames: ["category-helicopter"])
        let manager = AircraftAssetManager(providers: [
            BundledAircraftAssetProvider(imageLocator: locator),
            CategoryPlaceholderAssetProvider(imageLocator: locator),
            SystemSymbolAssetProvider()
        ])

        let asset = manager.resolve(
            AircraftAssetRequest(aircraftCode: "r22", category: .helicopter)
        )

        #expect(asset.source == .categoryPlaceholder)
        #expect(asset.content == .bundleImage(resourceName: "category-helicopter"))
    }

    @Test func categorySystemSymbolIsUsedWhenNoCategoryIllustrationExists() {
        let locator = FakeBundleImageLocator(availableNames: [])
        let manager = AircraftAssetManager(providers: [
            BundledAircraftAssetProvider(imageLocator: locator),
            CategoryPlaceholderAssetProvider(imageLocator: locator),
            SystemSymbolAssetProvider()
        ])

        let asset = manager.resolve(
            AircraftAssetRequest(aircraftCode: "r22", category: .helicopter)
        )

        #expect(asset.source == .categoryPlaceholder)
        #expect(asset.content == .systemSymbol(name: AircraftCategory.helicopter.assetSystemImage))
    }

    @Test func systemSymbolFallbackWhenCategoryUnknownAndNoBundledArt() {
        let locator = FakeBundleImageLocator(availableNames: [])
        let manager = AircraftAssetManager(providers: [
            BundledAircraftAssetProvider(imageLocator: locator),
            CategoryPlaceholderAssetProvider(imageLocator: locator),
            SystemSymbolAssetProvider()
        ])

        let asset = manager.resolve(AircraftAssetRequest(aircraftCode: "unknown_jet"))

        #expect(asset.source == .systemSymbol)
        #expect(asset.content == .systemSymbol(name: SystemSymbolAssetProvider.fallbackSystemImage))
    }

    @Test func resolveIsCachedSoProvidersAreNotReconsulted() {
        let provider = CountingProvider(
            providerID: "counting",
            asset: AircraftAsset(
                content: .systemSymbol(name: "airplane"),
                source: .systemSymbol,
                cacheKey: "unused"
            )
        )
        let manager = AircraftAssetManager(providers: [provider])
        let request = AircraftAssetRequest(aircraftCode: "c172", category: .generalAviation)

        _ = manager.resolve(request)
        _ = manager.resolve(request)

        #expect(provider.resolveCount == 1)
    }

    @Test func clearCacheForcesProvidersToRunAgain() {
        let provider = CountingProvider(
            providerID: "counting",
            asset: AircraftAsset(
                content: .systemSymbol(name: "airplane"),
                source: .systemSymbol,
                cacheKey: "unused"
            )
        )
        let manager = AircraftAssetManager(providers: [provider])
        let request = AircraftAssetRequest(aircraftCode: "c172")

        _ = manager.resolve(request)
        manager.clearCache()
        _ = manager.resolve(request)

        #expect(provider.resolveCount == 2)
    }

    @Test func emptyAircraftCodeSkipsBundledProvider() {
        let locator = FakeBundleImageLocator(availableNames: ["category-airliner"])
        let bundled = BundledAircraftAssetProvider(imageLocator: locator)

        #expect(bundled.resolve(AircraftAssetRequest(aircraftCode: "", category: .airliner)) == nil)
    }
}
