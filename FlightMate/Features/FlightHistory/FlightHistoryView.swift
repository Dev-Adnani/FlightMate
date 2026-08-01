//
//  FlightHistoryView.swift
//  FlightMate
//
//  Product Flight History: current flight timeline + earlier flights log
//  (this session's in-memory flights plus the persisted logbook from
//  previous sessions). Debug inspector lives under Settings → Developer.
//

import SwiftUI

struct FlightHistoryView: View {
    @StateObject private var viewModel: FlightHistoryViewModel
    @ObservedObject var unitPreferenceService: UnitPreferenceService

    init(
        flightHistoryEngine: FlightHistoryEngine,
        flightHistoryPersistenceService: FlightHistoryPersistenceService,
        unitPreferenceService: UnitPreferenceService
    ) {
        _viewModel = StateObject(
            wrappedValue: FlightHistoryViewModel(
                flightHistoryEngine: flightHistoryEngine,
                flightHistoryPersistenceService: flightHistoryPersistenceService
            )
        )
        self.unitPreferenceService = unitPreferenceService
    }

    var body: some View {
        NavigationSplitView {
            flightList
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let item = viewModel.selectedHistory {
                FlightHistoryDetailPane(item: item, unitSystem: unitPreferenceService.unitSystem)
            } else {
                EmptyStateView(
                    systemImage: "clock",
                    title: "No flight yet",
                    message: "Load an aircraft in Aerofly, then take off — one flight is takeoff to landing."
                )
            }
        }
        .navigationTitle("Flight History")
    }

    private var flightList: some View {
        List(selection: $viewModel.selectedHistoryID) {
            if let current = viewModel.currentHistory {
                Section("Current flight") {
                    FlightHistoryRow(item: .live(current), isCurrent: true)
                        .tag(current.id)
                }
            }

            if !viewModel.earlierFlights.isEmpty {
                Section("Earlier flights") {
                    ForEach(viewModel.earlierFlights) { item in
                        FlightHistoryRow(item: item, isCurrent: false)
                            .tag(item.id)
                    }
                }
            }
        }
        .overlay {
            if viewModel.currentHistory == nil, viewModel.earlierFlights.isEmpty {
                EmptyStateView(
                    systemImage: "airplane.departure",
                    title: "Waiting for a flight",
                    message: "Take off in Aerofly to start the flight clock."
                )
            }
        }
    }
}

private struct FlightHistoryRow: View {
    let item: FlightHistoryListItem
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.aircraftLabel)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(statusLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            Text(routeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(durationLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var routeLabel: String {
        let dep = item.departureICAO ?? "—"
        let dest = item.destinationICAO ?? "—"
        return "\(dep) → \(dest)"
    }

    private var durationLabel: String {
        if let seconds = item.flightDurationSeconds {
            return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
        }
        return isCurrent ? "Preflight" : "—"
    }

    private var statusLabel: String {
        switch item.status {
        case .active: return item.hasStartedFlight ? "In progress" : "Preflight"
        case .completed: return "Completed"
        case .aborted: return "Aborted"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .active: return item.hasStartedFlight ? Theme.color(for: .healthy) : Theme.color(for: .informational)
        case .completed: return Theme.color(for: .informational)
        case .aborted: return Theme.color(for: .warning)
        }
    }
}

private struct FlightHistoryDetailPane: View {
    let item: FlightHistoryListItem
    let unitSystem: UnitSystem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                DetailHeader(
                    title: item.aircraftLabel,
                    subtitle: routeSubtitle,
                    badge: badge
                )

                metrics

                if let events = item.events {
                    VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                        Text("Timeline")
                            .font(Theme.Typography.section)
                        ForEach(events, id: \.eventId) { event in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 72, alignment: .leading)
                                Label(event.type.displayName, systemImage: event.type.systemImage)
                                    .font(.body)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                } else {
                    Text("From a previous session — full timeline isn't saved, only this summary.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.dashboardPadding)
            .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var routeSubtitle: String {
        let dep = item.departureICAO ?? "—"
        let dest = item.destinationICAO ?? "—"
        return "\(dep) → \(dest)"
    }

    private var badge: String? {
        switch item.status {
        case .active: return item.hasStartedFlight ? "In progress" : "Preflight"
        case .completed: return "Completed"
        case .aborted: return "Aborted"
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: Theme.Spacing.contentGap
        ) {
            metric("Duration", durationText)
            metric("Events", item.events.map { "\($0.count)" } ?? "—")
            metric("Started", item.startTime.formatted(date: .abbreviated, time: .shortened))
            metric(
                "Takeoff",
                item.takeoffTime?.formatted(date: .omitted, time: .shortened) ?? "—"
            )
            metric("Max Altitude", maxAltitudeText)
            metric("Max Speed", maxGroundSpeedText)
            metric("Avg Speed", averageGroundSpeedText)
        }
    }

    private var durationText: String {
        item.flightDurationSeconds.map {
            Duration.seconds($0).formatted(.time(pattern: .hourMinuteSecond))
        } ?? "—"
    }

    private var maxAltitudeText: String {
        UnitFormatting.altitude(feet: item.maxAltitudeFeet, system: unitSystem)
    }

    private var maxGroundSpeedText: String {
        UnitFormatting.speed(knots: item.maxGroundSpeedKnots, system: unitSystem)
    }

    private var averageGroundSpeedText: String {
        UnitFormatting.speed(knots: item.averageGroundSpeedKnots, system: unitSystem)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    FlightHistoryView(
        flightHistoryEngine: flightHistoryEngine,
        flightHistoryPersistenceService: FlightHistoryPersistenceService(
            flightHistoryEngine: flightHistoryEngine,
            persistenceService: PersistenceService(isStoredInMemoryOnly: true)
        ),
        unitPreferenceService: UnitPreferenceService()
    )
}
