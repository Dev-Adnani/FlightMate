//
//  SettingsView.swift
//  FlightMate
//
//  About + Developer diagnostics. Preference panes appear when there is
//  real state to configure — not as empty placeholders.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine,
        unitPreferenceService: UnitPreferenceService
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                unitPreferenceService: unitPreferenceService
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedSection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch viewModel.selectedSection {
            case .about:
                SettingsAboutView()
            case .units:
                UnitsSettingsView(unitPreferenceService: viewModel.unitPreferenceService)
            case .developer:
                DeveloperToolsView(
                    telemetryService: viewModel.telemetryService,
                    flightContextEngine: viewModel.flightContextEngine,
                    flightAnalysisEngine: viewModel.flightAnalysisEngine,
                    flightEventEngine: viewModel.flightEventEngine,
                    flightHistoryEngine: viewModel.flightHistoryEngine
                )
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    SettingsView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: flightEventEngine,
        flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine),
        unitPreferenceService: UnitPreferenceService()
    )
}
