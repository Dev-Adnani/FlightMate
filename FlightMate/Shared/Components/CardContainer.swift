//
//  CardContainer.swift
//  FlightMate
//
//  Reusable SwiftUI components shared across Features live in this folder.
//

import SwiftUI

/// The shared visual chrome every dashboard-style card is built from: a
/// title row (SF Symbol + label) over caller-supplied content, on a
/// rounded, material background.
///
/// Deliberately generic and feature-agnostic -- nothing here knows about
/// flights, telemetry, or aviation -- so any future screen (Statistics,
/// Checklist Progress, Weather) can reuse the exact same card look without
/// duplicating this styling.
struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CardContainer(title: "Example Card", systemImage: "airplane") {
        Text("Card content goes here.")
    }
    .padding()
    .frame(width: 320)
}
