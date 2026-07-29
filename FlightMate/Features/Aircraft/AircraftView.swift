//
//  AircraftView.swift
//  FlightMate
//
//  Master–detail browser over bundled Aerofly aircraft reference data.
//

import SwiftUI

struct AircraftView: View {
    @StateObject private var viewModel: AircraftViewModel

    init(
        aircraftProvider: AircraftProviding,
        flightAnalysisEngine: FlightAnalysisEngine,
        aircraftAssetManager: AircraftAssetManaging
    ) {
        _viewModel = StateObject(
            wrappedValue: AircraftViewModel(
                aircraftProvider: aircraftProvider,
                flightAnalysisEngine: flightAnalysisEngine,
                aircraftAssetManager: aircraftAssetManager
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            aircraftList
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if let aircraft = viewModel.selectedAircraft {
                AircraftDetailPane(
                    aircraft: aircraft,
                    liveries: viewModel.selectedLiveries,
                    asset: viewModel.selectedAsset,
                    isCurrent: aircraft.aeroflyCode == viewModel.currentAircraftCode
                )
            } else {
                EmptyStateView(
                    systemImage: "airplane",
                    title: "Select an aircraft",
                    message: "Browse Aerofly types from the list."
                )
            }
        }
        .navigationTitle("Aircraft")
    }

    private var aircraftList: some View {
        List(selection: $viewModel.selectedAircraftID) {
            ForEach(viewModel.filteredAircraft) { aircraft in
                AircraftRow(
                    aircraft: aircraft,
                    isCurrent: aircraft.aeroflyCode == viewModel.currentAircraftCode
                )
                .tag(aircraft.id)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search aircraft")
        .overlay {
            if viewModel.filteredAircraft.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    message: "Try a different name, ICAO, or Aerofly code."
                )
            }
        }
    }
}

private struct AircraftRow: View {
    let aircraft: Aircraft
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.nameFull)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(aircraft.icaoCode) · \(aircraft.category.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isCurrent {
                Text("Current")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.color(for: .healthy))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct AircraftDetailPane: View {
    let aircraft: Aircraft
    let liveries: [AircraftLivery]
    let asset: AircraftAsset?
    let isCurrent: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                HStack(alignment: .top, spacing: 20) {
                    if let asset {
                        AircraftAssetImage(asset: asset, font: .system(size: 56))
                            .frame(width: 88, height: 88)
                    }
                    DetailHeader(
                        title: aircraft.nameFull,
                        subtitle: "\(aircraft.icaoCode) · \(aircraft.aeroflyCode)",
                        badge: isCurrent ? "Current" : nil
                    )
                }

                metricsGrid

                if !liveries.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
                        Text("Liveries")
                            .font(Theme.Typography.section)
                        ForEach(liveries, id: \.aeroflyCode) { livery in
                            HStack {
                                Text(livery.name)
                                Spacer()
                                if let icao = livery.icaoCode {
                                    Text(icao)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.dashboardPadding)
            .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: Theme.Spacing.contentGap
        ) {
            metric("Category", aircraft.category.displayName)
            metric("Cruise", "\(Int(aircraft.cruiseSpeedKts)) kt · \(Int(aircraft.cruiseAltitudeFt)) ft")
            metric("Approach", "\(Int(aircraft.approachAirspeedKts)) kt")
            metric("Range", "\(Int(aircraft.maximumRangeNm)) nm")
        }
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
    let analysis = FlightAnalysisEngine(
        flightContextEngine: FlightContextEngine(
            telemetryService: TelemetryService(),
            aeroflySessionService: AeroflySessionService()
        )
    )
    AircraftView(
        aircraftProvider: AircraftService(),
        flightAnalysisEngine: analysis,
        aircraftAssetManager: AircraftAssetManager()
    )
}
