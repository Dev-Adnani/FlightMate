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
/// `FlightContextEngine` so `DashboardView` can surface their debug
/// views. Dashboard-specific presentation logic will be added as the
/// feature grows. `FlightHistoryEngine` is no longer surfaced here --
/// Flight History is its own top-level `NavigationDestination` now (see
/// `FlightHistoryView`).
@MainActor
final class DashboardViewModel: ObservableObject {
    let telemetryService: TelemetryService
    let flightContextEngine: FlightContextEngine

    init(
        telemetryService: TelemetryService,
        flightContextEngine: FlightContextEngine
    ) {
        self.telemetryService = telemetryService
        self.flightContextEngine = flightContextEngine
    }
}
