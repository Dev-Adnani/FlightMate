//
//  AircraftAssetImage.swift
//  FlightMate
//
//  Shared SwiftUI rendering helper for AircraftAsset. The only place in
//  the UI that knows how to turn AircraftAssetContent into an Image --
//  Views pass an AircraftAsset and never branch on provider identity.
//

import SwiftUI

/// Renders a resolved `AircraftAsset` as a SwiftUI `Image`.
struct AircraftAssetImage: View {
    let asset: AircraftAsset
    var font: Font = .system(size: 36)
    var isEmphasized: Bool = true

    var body: some View {
        Group {
            switch asset.content {
            case .bundleImage(let resourceName):
                Image(resourceName)
                    .resizable()
                    .scaledToFit()
            case .systemSymbol(let name):
                Image(systemName: name)
                    .font(font)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isEmphasized ? .primary : .tertiary)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        AircraftAssetImage(
            asset: AircraftAsset(
                content: .systemSymbol(name: "airplane.circle.fill"),
                source: .systemSymbol,
                cacheKey: "preview"
            )
        )
        AircraftAssetImage(
            asset: AircraftAsset(
                content: .systemSymbol(name: "helicopter"),
                source: .categoryPlaceholder,
                cacheKey: "heli"
            )
        )
    }
    .padding()
}
