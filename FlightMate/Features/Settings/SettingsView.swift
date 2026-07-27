//
//  SettingsView.swift
//  FlightMate
//
//  App preferences and configuration. UI to be designed.
//

import SwiftUI

/// Placeholder root view for the Settings feature.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Text("Settings")
    }
}

#Preview {
    SettingsView()
}
