//
//  CardContainer.swift
//  FlightMate
//
//  Shared visual chrome for dashboard-style cards: glass surface, clear
//  title, soft fills the bento cell evenly.
//

import SwiftUI

/// Shared card chrome: title row + content on a quiet rounded glass surface.
///
/// Fills its parent cell so bento rows stay even.
struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    var accent: Color = Theme.Colors.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .accessibilityAddTraits(.isHeader)

            content()
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Theme.Colors.cardStroke,
                                    accent.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CardContainer(title: "Example", systemImage: "airplane") {
        Text("Content")
            .font(Theme.Typography.metric)
    }
    .padding()
    .frame(width: 320, height: 160)
    .background(Theme.dashboardBackground)
}
