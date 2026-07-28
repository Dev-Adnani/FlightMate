//
//  SettingsView.swift
//  FlightMate
//
//  App preferences and configuration, plus the Developer Tools diagnostics
//  panel (see DeveloperToolsView) that replaces the debug views that used
//  to live directly on the Dashboard.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine
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
            destinationView(for: viewModel.selectedSection)
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private func destinationView(for section: SettingsSection) -> some View {
        switch section {
        case .general, .appearance, .ai, .telemetry:
            SettingsComingSoonView(section: section)
        case .developer:
            DeveloperToolsView(
                telemetryService: viewModel.telemetryService,
                flightContextEngine: viewModel.flightContextEngine,
                flightAnalysisEngine: viewModel.flightAnalysisEngine,
                flightEventEngine: viewModel.flightEventEngine
            )
        }
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    SettingsView(
        telemetryService: telemetryService,
        flightContextEngine: flightContextEngine,
        flightAnalysisEngine: flightAnalysisEngine,
        flightEventEngine: FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    )
}
