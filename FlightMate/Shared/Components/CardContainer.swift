//
//  CardContainer.swift
//  FlightMate
//
//  Shared visual chrome for dashboard-style cards: quiet surface, clear
//  title, content fills the bento cell evenly.
//

import SwiftUI

/// Shared card chrome: title row + content on a quiet rounded surface.
///
/// Fills its parent cell so bento rows stay even.
struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
                .accessibilityAddTraits(.isHeader)

            content()
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CardContainer(title: "Example", systemImage: "airplane") {
        Text("Content")
    }
    .padding()
    .frame(width: 320, height: 160)
}
