//
//  TelemetryService.swift
//  FlightMate
//
//  Owns the live connection to Aerofly FS 4 and publishes decoded telemetry
//  to the rest of the app. Intentionally not implemented yet.
//

import Combine
import Foundation

/// Coordinates ingestion of live telemetry (via UDPListener) and publishes it
/// for consumption by FlightContext and the UI layer.
/// Implementation to be added.
final class TelemetryService: ObservableObject {
    @Published private(set) var latestTelemetry: TelemetryData?
}
