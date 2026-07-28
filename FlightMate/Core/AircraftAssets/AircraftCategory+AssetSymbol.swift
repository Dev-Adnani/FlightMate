//
//  AircraftCategory+AssetSymbol.swift
//  FlightMate
//
//  SF Symbol stand-ins for each AircraftCategory, used by the category
//  placeholder provider when no bundled category illustration is shipped
//  yet. Kept on AircraftCategory (not in a View) so the asset layer stays
//  UIKit/SwiftUI-free.
//

import Foundation

extension AircraftCategory {
    /// SF Symbol used when no FlightMate-bundled category illustration
    /// exists for this category. Deliberately simple, well-established
    /// symbols -- no invented cockpit iconography.
    var assetSystemImage: String {
        switch self {
        case .airliner: return "airplane"
        case .generalAviation: return "airplane"
        case .military: return "airplane"
        case .historical: return "airplane"
        case .helicopter: return "helicopter"
        case .aerobatic: return "airplane"
        case .glider: return "airplane"
        }
    }

    /// Bundle resource name for a future category illustration, without
    /// extension -- e.g. `"category-airliner"`. Matches the naming
    /// convention documented in `Resources/Aircraft/Assets/Assets.md`.
    var assetResourceName: String {
        "category-\(rawValue)"
    }
}
