//
//  BundleImageLooking.swift
//  FlightMate
//
//  Tiny seam over Bundle image lookup so providers stay unit-testable
//  without shipping real PNG fixtures.
//

import Foundation

/// Looks up a named image resource in an app bundle.
protocol BundleImageLooking {
    /// - Returns: `true` if a renderable image named `resourceName` exists
    ///   in the bundle (any supported extension).
    func hasImage(named resourceName: String) -> Bool
}

/// Default implementation backed by `Bundle`. Uses `url(forResource:)` for
/// common image extensions rather than `NSImage(named:)`, so this file
/// stays AppKit-free and testable from pure Foundation tests.
struct BundleImageLocator: BundleImageLooking {
    private static let imageExtensions = ["png", "webp", "jpg", "jpeg"]

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func hasImage(named resourceName: String) -> Bool {
        Self.imageExtensions.contains { ext in
            bundle.url(forResource: resourceName, withExtension: ext) != nil
        }
    }
}
