//
//  SettingsViewModel.swift
//  FlightMate
//
//  Passthrough holder for Settings destinations and Developer diagnostics.
//

import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .about

    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine
    let flightHistoryEngine: FlightHistoryEngine
    let unitPreferenceService: UnitPreferenceService

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine,
        unitPreferenceService: UnitPreferenceService
    ) {
        self.telemetryService = telemetryService
        self.flightContextEngine = flightContextEngine
        self.flightAnalysisEngine = flightAnalysisEngine
        self.flightEventEngine = flightEventEngine
        self.flightHistoryEngine = flightHistoryEngine
        self.unitPreferenceService = unitPreferenceService
    }
}
