//
//  AirportView.swift
//  FlightMate
//
//  Search-first airport browser over bundled Aerofly airport reference data.
//

import SwiftUI

struct AirportView: View {
    @StateObject private var viewModel: AirportViewModel

    init(
        airportProvider: AirportProviding,
        flightAnalysisEngine: FlightAnalysisEngine
    ) {
        _viewModel = StateObject(
            wrappedValue: AirportViewModel(
                airportProvider: airportProvider,
                flightAnalysisEngine: flightAnalysisEngine
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            airportList
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let airport = viewModel.selectedAirport {
                AirportDetailPane(
                    airport: airport,
                    role: viewModel.roleLabel(for: airport.icaoCode)
                )
            } else {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Find an airport",
                    message: "Search by ICAO, name, or city. Live departure, destination, and nearest appear when flying."
                )
            }
        }
        .navigationTitle("Airports")
    }

    private var airportList: some View {
        List(selection: $viewModel.selectedICAO) {
            if !viewModel.suggestedAirports.isEmpty, viewModel.searchText.isEmpty {
                Section("This flight") {
                    ForEach(viewModel.suggestedAirports) { airport in
                        AirportRow(airport: airport, role: viewModel.roleLabel(for: airport.icaoCode))
                            .tag(airport.icaoCode)
                    }
                }
            }

            if !viewModel.results.isEmpty {
                Section("Results") {
                    ForEach(viewModel.results) { airport in
                        AirportRow(airport: airport, role: viewModel.roleLabel(for: airport.icaoCode))
                            .tag(airport.icaoCode)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "ICAO, name, or city")
        .overlay {
            if viewModel.searchText.isEmpty, viewModel.suggestedAirports.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Search airports",
                    message: "Try KSFO, London, or your departure ICAO."
                )
            } else if !viewModel.searchText.isEmpty, viewModel.results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    message: "Check the spelling or try a 4-letter ICAO."
                )
            }
        }
    }
}

private struct AirportRow: View {
    let airport: Airport
    let role: String?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(airport.icaoCode)
                    .font(.body.weight(.semibold).monospaced())
                Text(airport.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let role {
                Text(role)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.color(for: .informational))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct AirportDetailPane: View {
    let airport: Airport
    let role: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                DetailHeader(
                    title: airport.icaoCode,
                    subtitle: airport.name,
                    badge: role
                )

                AirportMapPreview(airport: airport)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: Theme.Spacing.contentGap
                ) {
                    metric("Municipality", airport.municipality ?? "—")
                    metric("Category", categoryLabel(airport.category))
                    metric("Elevation", airport.elevationFt.map { "\(Int($0)) ft" } ?? "—")
                    metric(
                        "Coordinates",
                        String(format: "%.4f, %.4f", airport.latitude, airport.longitude)
                    )
                }
            }
            .padding(Theme.Spacing.dashboardPadding)
            .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func categoryLabel(_ category: AirportCategory?) -> String {
        guard let category else { return "—" }
        switch category {
        case .largeAirport: return "Large airport"
        case .mediumAirport: return "Medium airport"
        case .smallAirport: return "Small airport"
        case .largeAirbase: return "Large airbase"
        case .mediumAirbase: return "Medium airbase"
        case .smallAirbase: return "Small airbase"
        case .privateAirfield: return "Private airfield"
        case .heliport: return "Heliport"
        case .closed: return "Closed"
        }
    }
}

#Preview {
    let analysis = FlightAnalysisEngine(
        flightContextEngine: FlightContextEngine(
            telemetryService: TelemetryService(),
            aeroflySessionService: AeroflySessionService()
        )
    )
    AirportView(airportProvider: AirportService(), flightAnalysisEngine: analysis)
}
