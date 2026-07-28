//
//  SettingsComingSoonView.swift
//  FlightMate
//
//  Shared placeholder for Settings sections that don't have real
//  preferences yet (General, Appearance, AI, Telemetry).
//

import SwiftUI

struct SettingsComingSoonView: View {
    let section: SettingsSection

    var body: some View {
        ContentUnavailableView(
            section.title,
            systemImage: section.systemImage,
            description: Text("\(section.title) settings are coming soon.")
        )
        .navigationTitle(section.title)
    }
}

#Preview {
    SettingsComingSoonView(section: .general)
}
