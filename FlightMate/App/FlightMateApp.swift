//
//  FlightMateApp.swift
//  FlightMate
//
//  Created by Dev Adnani on 27/07/26.
//

import SwiftUI
import SwiftData

@main
struct FlightMateApp: App {
    /// True when this process was launched as the unit test bundle's host
    /// app (`FlightMateTests`'s `TEST_HOST` build setting runs unit tests
    /// *inside* this real `FlightMate` executable, not a separate xctest
    /// process). `FlightMateApp`'s body still runs in that case, so without
    /// this guard every `xcodebuild test` invocation would also bind a
    /// second, fully real `UDPListener` to ``TelemetryService/defaultPort``
    /// — colliding with a manually-run app instance still open on the same
    /// Mac (`EADDRINUSE` on bind). Unit tests already construct their own
    /// `TelemetryService`/`AeroflySessionService` fakes/instances directly
    /// and never rely on this app-level `.task` wiring.
    private static var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    /// Single composition-root owner for every app-wide service. Held as
    /// one `@StateObject` so SwiftUI tracks container lifetime without
    /// re-rendering the scene on every UDP/`main.mcf` publish -- see
    /// `AppServices`.
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            // Unit tests run inside this host app via `TEST_HOST`. Skip the
            // real UI (and its view-model Combine subscriptions) so test
            // suites aren't fighting Dashboard/MapKit for the MainActor.
            if Self.isRunningUnitTests {
                EmptyView()
            } else {
                ContentView(
                    telemetryService: services.telemetryService,
                    flightAnalysisEngine: services.flightAnalysisEngine,
                    flightContextEngine: services.flightContextEngine,
                    flightEventEngine: services.flightEventEngine,
                    flightHistoryEngine: services.flightHistoryEngine,
                    mapTrailService: services.mapTrailService,
                    aircraftAssetManager: services.aircraftAssetManager,
                    aircraftProvider: services.aircraftService,
                    airportProvider: services.airportService,
                    procedureProvider: services.procedureService,
                    unitPreferenceService: services.unitPreferenceService,
                    flightHistoryPersistenceService: services.flightHistoryPersistenceService,
                    liveWeatherService: services.liveWeatherService,
                    simBriefService: services.simBriefService,
                    simBriefPreferenceService: services.simBriefPreferenceService,
                    aeroflyMcfWriter: services.aeroflyMcfWriter
                )
                .task {
                    do {
                        try await services.telemetryService.start()
                    } catch {
                        // Failure is already reflected in `telemetryService.status`
                        // and surfaced via TelemetryDebugView; nothing else to do here.
                    }
                }
                .task {
                    services.aeroflySessionService.start()
                }
            }
        }
        .modelContainer(services.persistenceService.modelContainer)
        .defaultSize(width: 1180, height: 760)
    }
}
