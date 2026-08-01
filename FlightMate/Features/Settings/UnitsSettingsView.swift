//
//  UnitsSettingsView.swift
//  FlightMate
//
//  Settings > Units: choose Imperial or Metric display units. Applies
//  everywhere immediately -- no separate "Apply" step -- since
//  UnitPreferenceService is @Published and every consumer subscribes
//  live.
//

import SwiftUI

struct UnitsSettingsView: View {
    @ObservedObject var unitPreferenceService: UnitPreferenceService

    var body: some View {
        Form {
            Section {
                Picker("Display units", selection: $unitPreferenceService.unitSystem) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Applies to altitude, speed, and distance readouts across the app.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 420)
        .navigationSubtitle("Units")
    }
}

#Preview {
    UnitsSettingsView(unitPreferenceService: UnitPreferenceService())
}
