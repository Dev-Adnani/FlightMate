//
//  SettingsViewModel.swift
//  FlightMate
//
//  Drives SettingsView. Mostly a passthrough today -- Settings has no
//  derived/business state of its own yet -- but gives Developer Tools a
//  single, consistent place to receive the engines it displays raw, and
//  gives future General/Appearance/AI/Telemetry sections a home for real
//  preferences later.
//

import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .general

    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine
    ) {
        self.telemetryService = telemetryService
        self.flightContextEngine = flightContextEngine
        self.flightAnalysisEngine = flightAnalysisEngine
        self.flightEventEngine = flightEventEngine
    }
}
