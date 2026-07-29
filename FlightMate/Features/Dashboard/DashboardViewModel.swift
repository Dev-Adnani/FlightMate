//
//  DashboardViewModel.swift
//  FlightMate
//
//  Drives DashboardView: aggregates FlightContextEngine, FlightAnalysisEngine,
//  FlightEventEngine, and FlightHistoryEngine into small, independent,
//  per-card display models. Owns no interpretation logic of its own --
//  every card model's actual field-by-field mapping lives on that model's
//  own `from(...)` factory (Features/Dashboard/Models), mirroring how every
//  Core engine in this codebase delegates interpretation to a pure service
//  and only owns wiring.
//

import Combine
import Foundation

/// View model for the Dashboard feature -- FlightMate's primary workspace.
///
/// ## Dependency injection
/// Not a singleton. Consumes four already-injected engines plus an
/// `AircraftAssetManaging` and never reaches for a shared/global instance.
/// `FlightContextEngine` is included alongside the three higher-level
/// engines specifically for the small set of fields `FlightAnalysis`
/// deliberately excludes (raw altitude/ground speed/heading, session
/// state) -- see `TelemetryCardModel`'s and `ConnectionStatusCardModel`'s
/// doc comments. Individual cards never see any engine or the asset
/// manager directly; they only ever receive the small, Equatable model
/// this view model publishes for them.
///
/// ## Performance
/// Each `@Published` card model is only reassigned when its own
/// `Equatable` value actually changes, even though the underlying engines
/// (especially `FlightContextEngine`, which updates at UDP telemetry
/// rates) publish far more often than that -- so a card whose data hasn't
/// changed never causes SwiftUI to re-render it.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var aircraft: AircraftCardModel = .noSelection
    @Published private(set) var flightPhase: FlightPhaseCardModel = .idle
    @Published private(set) var navigation: NavigationCardModel = .empty
    @Published private(set) var telemetry: TelemetryCardModel = .empty
    @Published private(set) var flightDuration: FlightDurationCardModel = .empty
    @Published private(set) var recentEvents: RecentEventsCardModel = .empty
    @Published private(set) var connectionStatus: ConnectionStatusCardModel = .empty

    private let aircraftAssetManager: AircraftAssetManaging
    private var latestContext: FlightContext
    private var latestAnalysis: FlightAnalysis
    private var cancellables: Set<AnyCancellable> = []

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        flightEventEngine: FlightEventEngine,
        flightHistoryEngine: FlightHistoryEngine,
        aircraftAssetManager: AircraftAssetManaging = AircraftAssetManager()
    ) {
        self.aircraftAssetManager = aircraftAssetManager
        latestContext = flightContextEngine.context
        latestAnalysis = flightAnalysisEngine.analysis

        // Deliveries are scheduled asynchronously on the main queue so
        // `@Published` mutations never happen synchronously inside a
        // SwiftUI view update (View/`@StateObject` construction, or an
        // overlapping MapKit layout pass). `receive(on:)` plus an explicit
        // `async` hop is deliberate — engine publishes can otherwise land
        // inside a view/layout turn and trip "Publishing changes from
        // within view updates is not allowed".
        flightContextEngine.$context
            .receive(on: DispatchQueue.main)
            .sink { [weak self] context in
                DispatchQueue.main.async {
                    self?.latestContext = context
                    self?.refreshContextDerivedCards()
                }
            }
            .store(in: &cancellables)

        flightAnalysisEngine.$analysis
            .receive(on: DispatchQueue.main)
            .sink { [weak self] analysis in
                DispatchQueue.main.async {
                    self?.latestAnalysis = analysis
                    self?.refreshAnalysisDerivedCards()
                }
            }
            .store(in: &cancellables)

        flightEventEngine.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                DispatchQueue.main.async {
                    self?.updateRecentEvents(events)
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(flightHistoryEngine.$currentHistory, flightHistoryEngine.$completedHistories)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current, completed in
                DispatchQueue.main.async {
                    self?.updateFlightDuration(current: current, completed: completed)
                }
            }
            .store(in: &cancellables)
    }

    /// Cards driven purely by `FlightAnalysis`.
    private func refreshAnalysisDerivedCards() {
        setIfChanged(\.aircraft, AircraftCardModel.from(latestAnalysis, assetManager: aircraftAssetManager))
        setIfChanged(\.flightPhase, FlightPhaseCardModel.from(latestAnalysis))
        refreshCombinedCards()
    }

    /// Cards driven by `FlightContext` alone, or by both `FlightContext`
    /// and `FlightAnalysis` together.
    private func refreshContextDerivedCards() {
        refreshCombinedCards()
    }

    /// Cards that need both the latest context and the latest analysis --
    /// recomputed whenever either source updates.
    private func refreshCombinedCards() {
        setIfChanged(\.navigation, NavigationCardModel.from(context: latestContext, analysis: latestAnalysis))
        setIfChanged(\.telemetry, TelemetryCardModel.from(context: latestContext, analysis: latestAnalysis))
        setIfChanged(\.connectionStatus, ConnectionStatusCardModel.from(context: latestContext, analysis: latestAnalysis))
    }

    private func updateRecentEvents(_ events: [FlightEvent]) {
        setIfChanged(\.recentEvents, RecentEventsCardModel.from(events: events))
    }

    private func updateFlightDuration(current: FlightHistory?, completed: [FlightHistory]) {
        setIfChanged(\.flightDuration, FlightDurationCardModel.from(current: current, completed: completed))
    }

    /// Assigns `newValue` to the `@Published` property at `keyPath` only if
    /// it actually differs from the current value -- the single choke
    /// point that keeps every card's redraw frequency tied to its own
    /// data, not to how often the upstream engines publish.
    private func setIfChanged<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<DashboardViewModel, Value>,
        _ newValue: Value
    ) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }
}
