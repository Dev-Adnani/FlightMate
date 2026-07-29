//
//  FlightHistoryView.swift
//  FlightMate
//
//  Product Flight History: current flight timeline + earlier flights log.
//  Debug inspector lives under Settings → Developer.
//

import SwiftUI

struct FlightHistoryView: View {
    @StateObject private var viewModel: FlightHistoryViewModel

    init(flightHistoryEngine: FlightHistoryEngine) {
        _viewModel = StateObject(
            wrappedValue: FlightHistoryViewModel(flightHistoryEngine: flightHistoryEngine)
        )
    }

    var body: some View {
        NavigationSplitView {
            flightList
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let history = viewModel.selectedHistory {
                FlightHistoryDetailPane(history: history)
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
                    FlightHistoryRow(history: current, isCurrent: true)
                        .tag(current.id)
                }
            }

            if !viewModel.earlierFlights.isEmpty {
                Section("Earlier flights") {
                    ForEach(viewModel.earlierFlights) { history in
                        FlightHistoryRow(history: history, isCurrent: false)
                            .tag(history.id)
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
    let history: FlightHistory
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(aircraftLabel)
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

    private var aircraftLabel: String {
        history.currentAircraft?.aircraft?.nameFull
            ?? history.currentAircraft?.aircraftCode
            ?? "Unknown aircraft"
    }

    private var routeLabel: String {
        let dep = history.departureAirport?.icaoCode ?? "—"
        let dest = history.destinationAirport?.icaoCode ?? "—"
        return "\(dep) → \(dest)"
    }

    private var durationLabel: String {
        if let seconds = history.flightDurationSeconds {
            return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
        }
        return isCurrent ? "Preflight" : "—"
    }

    private var statusLabel: String {
        switch history.status {
        case .active: return history.hasStartedFlight ? "In progress" : "Preflight"
        case .completed: return "Completed"
        case .aborted: return "Aborted"
        }
    }

    private var statusColor: Color {
        switch history.status {
        case .active: return history.hasStartedFlight ? Theme.color(for: .healthy) : Theme.color(for: .informational)
        case .completed: return Theme.color(for: .informational)
        case .aborted: return Theme.color(for: .warning)
        }
    }
}

private struct FlightHistoryDetailPane: View {
    let history: FlightHistory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                DetailHeader(
                    title: history.currentAircraft?.aircraft?.nameFull
                        ?? history.currentAircraft?.aircraftCode
                        ?? "Flight",
                    subtitle: routeSubtitle,
                    badge: badge
                )

                metrics

                VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                    Text("Timeline")
                        .font(Theme.Typography.section)
                    ForEach(history.events, id: \.eventId) { event in
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
            }
            .padding(Theme.Spacing.dashboardPadding)
            .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var routeSubtitle: String {
        let dep = history.departureAirport?.icaoCode ?? "—"
        let dest = history.destinationAirport?.icaoCode ?? "—"
        return "\(dep) → \(dest)"
    }

    private var badge: String? {
        switch history.status {
        case .active: return history.hasStartedFlight ? "In progress" : "Preflight"
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
            metric("Events", "\(history.events.count)")
            metric("Started", history.startTime.formatted(date: .abbreviated, time: .shortened))
            metric(
                "Takeoff",
                history.takeoffTime?.formatted(date: .omitted, time: .shortened) ?? "—"
            )
        }
    }

    private var durationText: String {
        history.flightDurationSeconds.map {
            Duration.seconds($0).formatted(.time(pattern: .hourMinuteSecond))
        } ?? "—"
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
    FlightHistoryView(flightHistoryEngine: FlightHistoryEngine(flightEventEngine: flightEventEngine))
}
