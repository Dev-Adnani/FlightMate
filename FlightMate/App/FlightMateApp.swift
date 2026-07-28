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
    /// Single, app-wide telemetry service. Owning it here (rather than
    /// inside a feature) ensures only one UDP listener is ever bound, and
    /// lets multiple features (Dashboard today, Context/AI later) share the
    /// same live packet stream.
    @StateObject private var telemetryService: TelemetryService

    /// Watches Aerofly's `main.mcf` session file, independent from
    /// `telemetryService`/UDP. Owning it here alongside `telemetryService`
    /// keeps both live sources at the same app-wide lifetime.
    @StateObject private var aeroflySessionService: AeroflySessionService

    /// Combines `telemetryService`'s raw packets and `aeroflySessionService`'s
    /// parsed session into one observable `FlightContext`. Constructed with
    /// both injected in `init` below — neither type is a singleton.
    @StateObject private var flightContextEngine: FlightContextEngine

    /// Interprets `flightContextEngine`'s published context into a
    /// `FlightAnalysis` (flight phase, climb/descent/turn detection,
    /// nearest airport, etc). Not consumed by any UI yet — available for
    /// `flightEventEngine` (and, later, AI) to build on.
    @StateObject private var flightAnalysisEngine: FlightAnalysisEngine

    /// Watches `flightAnalysisEngine`'s published analysis over time and
    /// publishes discrete `FlightEvent`s (aircraft loaded, entered
    /// cruise, flight completed, etc) whenever state actually
    /// transitions. Not consumed by any UI yet — available for the next
    /// milestones (Flight Recorder, Timeline, Checklists, Notifications,
    /// AI) to build on.
    @StateObject private var flightEventEngine: FlightEventEngine

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // `@StateObject`'s default-value expressions can't reference sibling
        // properties (there's no `self` yet at that point), so the
        // dependency chain is wired explicitly here instead: one
        // `TelemetryService` and one `AeroflySessionService` instance are
        // created, then both handed to `FlightContextEngine` via its
        // initializer.
        let telemetryService = TelemetryService()
        let aeroflySessionService = AeroflySessionService()
        _telemetryService = StateObject(wrappedValue: telemetryService)
        _aeroflySessionService = StateObject(wrappedValue: aeroflySessionService)
        let flightContextEngine = FlightContextEngine(
            telemetryService: telemetryService,
            aeroflySessionService: aeroflySessionService
        )
        _flightContextEngine = StateObject(wrappedValue: flightContextEngine)
        let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
        _flightAnalysisEngine = StateObject(wrappedValue: flightAnalysisEngine)
        _flightEventEngine = StateObject(
            wrappedValue: FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(telemetryService: telemetryService, flightContextEngine: flightContextEngine)
                .task {
                    do {
                        try await telemetryService.start()
                    } catch {
                        // Failure is already reflected in `telemetryService.status`
                        // and surfaced via TelemetryDebugView; nothing else to do here.
                    }
                }
                .task {
                    aeroflySessionService.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
