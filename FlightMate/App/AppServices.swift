//
//  AppServices.swift
//  FlightMate
//
//  Composition-root ownership for the app-wide service graph. Held by
//  FlightMateApp as a single @StateObject so SwiftUI observes *this*
//  container's lifetime -- not every high-frequency engine publish.
//

import Combine
import Foundation

/// Owns FlightMate's app-wide engines and services for the process lifetime.
///
/// ## Why a single container?
/// Putting `TelemetryService`, `FlightContextEngine`, `MapTrailService`,
/// etc. each as their own `@StateObject` on `FlightMateApp` made SwiftUI
/// re-evaluate the entire app scene on every UDP-driven `@Published`
/// change. That overlapped MapKit/view updates and produced
/// "Publishing changes from within view updates is not allowed" warnings.
///
/// This type is an `ObservableObject` only so `@StateObject` can own it.
/// It deliberately has **no** `@Published` properties and never calls
/// `objectWillChange` -- feature view models subscribe to the engines
/// they need and publish display state at a UI-safe cadence.
@MainActor
final class AppServices: ObservableObject {
    let telemetryService: TelemetryService
    let aeroflySessionService: AeroflySessionService
    let aircraftService: AircraftService
    let airportService: AirportService
    let flightContextEngine: FlightContextEngine
    let flightAnalysisEngine: FlightAnalysisEngine
    let flightEventEngine: FlightEventEngine
    let flightHistoryEngine: FlightHistoryEngine
    let mapTrailService: MapTrailService
    let aircraftAssetManager: AircraftAssetManaging

    init() {
        let telemetryService = TelemetryService()
        let aeroflySessionService = AeroflySessionService()
        let aircraftService = AircraftService()
        let airportService = AirportService()

        self.telemetryService = telemetryService
        self.aeroflySessionService = aeroflySessionService
        self.aircraftService = aircraftService
        self.airportService = airportService
        aircraftAssetManager = AircraftAssetManager()

        let flightContextEngine = FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: aeroflySessionService
        )
        self.flightContextEngine = flightContextEngine

        let domainResolver = DomainResolutionService(
            aircraftProvider: aircraftService,
            airportProvider: airportService
        )
        let flightAnalysisEngine = FlightAnalysisEngine(
            flightContextEngine: flightContextEngine,
            domainResolver: domainResolver,
            airportProvider: airportService
        )
        self.flightAnalysisEngine = flightAnalysisEngine

        let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
        self.flightEventEngine = flightEventEngine

        // Constructed immediately after `flightEventEngine` -- see
        // `FlightHistoryEngine`'s construction-order documentation.
        let flightHistoryEngine = FlightHistoryEngine(flightEventEngine: flightEventEngine)
        self.flightHistoryEngine = flightHistoryEngine

        mapTrailService = MapTrailService(
            flightContextEngine: flightContextEngine,
            flightHistoryEngine: flightHistoryEngine
        )
    }
}
