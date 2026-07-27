//
//  DashboardViewModel.swift
//  FlightMate
//
//  Drives DashboardView. Further implementation to be added.
//

import Combine
import Foundation

/// View model for the Dashboard feature.
///
/// For now this only holds the injected `TelemetryService` and
/// `FlightContextEngine` so `DashboardView` can surface their debug views.
/// Dashboard-specific presentation logic will be added as the feature grows.
@MainActor
final class DashboardViewModel: ObservableObject {
    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine

    init(telemetryService: TelemetryService, flightContextEngine: FlightContextEngine) {
        self.telemetryService = telemetryService
        self.flightContextEngine = flightContextEngine
    }
}
