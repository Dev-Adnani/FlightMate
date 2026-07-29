//
//  EmptyStateView.swift
//  FlightMate
//
//  Calm empty / hint surface used by browsers and history.
//

import SwiftUI

/// Sparse empty state: symbol, title, one supporting sentence.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.section)
        } description: {
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "airplane",
        title: "No aircraft",
        message: "Load an aircraft in Aerofly to begin."
    )
}
