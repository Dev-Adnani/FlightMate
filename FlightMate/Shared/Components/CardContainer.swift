//
//  CardContainer.swift
//  FlightMate
//
//  Reusable SwiftUI components shared across Features live in this folder.
//

import SwiftUI

/// A minimal, reusable container view. Styling to be defined by the design system.
struct CardContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}
