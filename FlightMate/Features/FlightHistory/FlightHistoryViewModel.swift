//
//  FlightHistoryViewModel.swift
//  FlightMate
//
//  Drives FlightHistoryView.
//

import Combine
import Foundation

/// View model for the Flight History feature.
///
/// Currently holds only the injected `FlightHistoryEngine` so
/// `FlightHistoryView` can surface `FlightHistoryDebugView`. A real
/// timeline UI (grouped by phase, scrollable, filterable) is a future
/// milestone -- see `PROJECT_CONTEXT.md`.
@MainActor
final class FlightHistoryViewModel: ObservableObject {
    let flightHistoryEngine: FlightHistoryEngine

    init(flightHistoryEngine: FlightHistoryEngine) {
        self.flightHistoryEngine = flightHistoryEngine
    }
}
