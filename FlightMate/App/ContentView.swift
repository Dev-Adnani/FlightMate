//
//  ContentView.swift
//  FlightMate
//
//  FlightMate's real application shell -- a sidebar of
//  `NavigationDestination`s driving a full-size detail view per section.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationDestination? = .dashboard
    @ObservedObject var telemetryService: TelemetryService
    @ObservedObject var flightAnalysisEngine: FlightAnalysisEngine

    let flightContextEngine: FlightContextEngine
    let flightEventEngine: FlightEventEngine
    let flightHistoryEngine: FlightHistoryEngine
    let mapTrailService: MapTrailService
    let aircraftAssetManager: AircraftAssetManaging
    let aircraftProvider: AircraftProviding
    let airportProvider: AirportProviding
    let procedureProvider: ProcedureProviding
    let unitPreferenceService: UnitPreferenceService
    let flightHistoryPersistenceService: FlightHistoryPersistenceService
    let liveWeatherService: LiveWeatherService
    let simBriefService: SimBriefService
    let simBriefPreferenceService: SimBriefPreferenceService
    let aeroflyMcfWriter: AeroflyMcfWriting

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            destinationView(for: selection ?? .dashboard)
        }
        .tint(Theme.Colors.accent)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Fly") {
                sidebarRow(.dashboard)
                sidebarRow(.flightSetup)
                sidebarRow(.movingMap)
                sidebarRow(.procedures)
            }
            Section("Reference") {
                sidebarRow(.aircraft)
                sidebarRow(.airports)
                sidebarRow(.flightHistory)
            }
            Section {
                sidebarRow(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Theme.Layout.sidebarMin,
            ideal: Theme.Layout.sidebarIdeal
        )
        .navigationTitle("FlightMate")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            connectionStrip
        }
    }

    private func sidebarRow(_ destination: NavigationDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage)
            .tag(destination)
            .symbolRenderingMode(.hierarchical)
    }

    private var connectionStrip: some View {
        let level = flightAnalysisEngine.analysis.telemetryHealth.healthLevel
        let label = flightAnalysisEngine.analysis.telemetryHealth.displayLabel
        return HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.color(for: level))
                .symbolEffect(.pulse, options: .repeating, isActive: level == .warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Telemetry")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(Theme.color(for: level))
                .frame(width: 8, height: 8)
                .shadow(color: Theme.color(for: level).opacity(0.5), radius: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Telemetry \(label)")
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                aircraftAssetManager: aircraftAssetManager,
                unitPreferenceService: unitPreferenceService
            )
        case .flightSetup:
            FlightSetupView(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                liveWeatherService: liveWeatherService,
                simBriefService: simBriefService,
                simBriefPreferenceService: simBriefPreferenceService,
                mcfWriter: aeroflyMcfWriter
            )
        case .movingMap:
            MovingMapView(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                mapTrailService: mapTrailService
            )
        case .flightHistory:
            FlightHistoryView(
                flightHistoryEngine: flightHistoryEngine,
                flightHistoryPersistenceService: flightHistoryPersistenceService,
                unitPreferenceService: unitPreferenceService
            )
        case .airports:
            AirportView(
                airportProvider: airportProvider,
                flightAnalysisEngine: flightAnalysisEngine
            )
        case .aircraft:
            AircraftView(
                aircraftProvider: aircraftProvider,
                flightAnalysisEngine: flightAnalysisEngine,
                aircraftAssetManager: aircraftAssetManager
            )
        case .procedures:
            ProceduresView(
                procedureProvider: procedureProvider,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine
            )
        case .settings:
            SettingsView(
                telemetryService: telemetryService,
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                flightEventEngine: flightEventEngine,
                flightHistoryEngine: flightHistoryEngine,
                unitPreferenceService: unitPreferenceService
            )
        }
    }
}

#Preview {
    let telemetryService = TelemetryService()
    let flightContextEngine = FlightContextEngine(
        telemetryService: telemetryService,
        aeroflySessionService: AeroflySessionService()
    )
    let flightAnalysisEngine = FlightAnalysisEngine(flightContextEngine: flightContextEngine)
    let flightEventEngine = FlightEventEngine(flightAnalysisEngine: flightAnalysisEngine)
    let flightHistoryEngine = FlightHistoryEngine(flightEventEngine: flightEventEngine)
    let persistenceService = PersistenceService(isStoredInMemoryOnly: true)
    ContentView(
        telemetryService: telemetryService,
        flightAnalysisEngine: flightAnalysisEngine,
        flightContextEngine: flightContextEngine,
        flightEventEngine: flightEventEngine,
        flightHistoryEngine: flightHistoryEngine,
        mapTrailService: MapTrailService(
            flightContextEngine: flightContextEngine,
            flightHistoryEngine: flightHistoryEngine
        ),
        aircraftAssetManager: AircraftAssetManager(),
        aircraftProvider: AircraftService(),
        airportProvider: AirportService(),
        procedureProvider: ProcedureService(),
        unitPreferenceService: UnitPreferenceService(),
        flightHistoryPersistenceService: FlightHistoryPersistenceService(
            flightHistoryEngine: flightHistoryEngine,
            persistenceService: persistenceService
        ),
        liveWeatherService: LiveWeatherService(),
        simBriefService: SimBriefService(preferences: SimBriefPreferenceService()),
        simBriefPreferenceService: SimBriefPreferenceService(),
        aeroflyMcfWriter: AeroflyMcfWriter()
    )
}
