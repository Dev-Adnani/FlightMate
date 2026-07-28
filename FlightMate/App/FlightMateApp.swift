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
    /// Mac and producing the exact "Address already in use" spam this
    /// guards against, deterministically, every time a test run overlaps a
    /// live debug run. Unit tests already construct their own
    /// `TelemetryService`/`AeroflySessionService` fakes/instances directly
    /// and never rely on this app-level `.task` wiring.
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

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

    /// Watches `flightEventEngine`'s published events over time and
    /// maintains the ordered, in-memory timeline of the current flight
    /// (plus a bounded log of previously completed/aborted ones this app
    /// session). Surfaced via the "Flight History" destination —
    /// available for the next milestones (Flight Recorder, Debrief,
    /// Statistics, AI) to build on.
    @StateObject private var flightHistoryEngine: FlightHistoryEngine

    /// Watches `flightContextEngine`'s live position and
    /// `flightHistoryEngine`'s current flight identity, and maintains a
    /// lightweight, sampled breadcrumb trail of the flight currently
    /// being recorded. Surfaced via the "Moving Map" destination —
    /// designed to be reused unchanged by future Replay/GPX-export/
    /// Flight Recorder consumers (see `MapTrailService`).
    @StateObject private var mapTrailService: MapTrailService

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
        let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
        _flightEventEngine = StateObject(wrappedValue: flightEventEngine)
        // Constructed immediately after `flightEventEngine`, before any
        // `.task`-driven `.start()` calls run below — see
        // `FlightHistoryEngine`'s construction-order documentation for why
        // this ordering matters.
        let flightHistoryEngine = FlightHistoryEngine(flightEventEngine: flightEventEngine)
        _flightHistoryEngine = StateObject(wrappedValue: flightHistoryEngine)
        // `MapTrailService` only ever consumes `@Published` sources
        // (`flightContextEngine.$context`, `flightHistoryEngine.$currentHistory`),
        // both of which replay their current value to new subscribers —
        // unlike `FlightHistoryEngine`'s `eventPublisher`, there is no
        // construction-order requirement here.
        _mapTrailService = StateObject(
            wrappedValue: MapTrailService(
                flightContextEngine: flightContextEngine,
                flightHistoryEngine: flightHistoryEngine
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                mapTrailService: mapTrailService
            )
                .task {
                    guard !Self.isRunningUnitTests else { return }
                    do {
                        try await telemetryService.start()
                    } catch {
                        // Failure is already reflected in `telemetryService.status`
                        // and surfaced via TelemetryDebugView; nothing else to do here.
                    }
                }
                .task {
                    guard !Self.isRunningUnitTests else { return }
                    aeroflySessionService.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
