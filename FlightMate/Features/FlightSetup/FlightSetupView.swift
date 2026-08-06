//
//  FlightSetupView.swift
//  FlightMate
//
//  Startgerät-inspired Flight Setup: aircraft, plan, weather, import/export.
//

import SwiftUI

struct FlightSetupView: View {
    @StateObject private var viewModel: FlightSetupViewModel

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        liveWeatherService: LiveWeatherService,
        simBriefService: SimBriefService,
        simBriefPreferenceService: SimBriefPreferenceService,
        mcfWriter: AeroflyMcfWriting
    ) {
        _viewModel = StateObject(
            wrappedValue: FlightSetupViewModel(
                flightContextEngine: flightContextEngine,
                flightAnalysisEngine: flightAnalysisEngine,
                liveWeatherService: liveWeatherService,
                simBriefService: simBriefService,
                simBriefPreferences: simBriefPreferenceService,
                mcfWriter: mcfWriter
            )
        )
    }

    var body: some View {
        Form {
            aircraftSection
            flightPlanSection
            weatherSection
            importExportSection
            if let status = viewModel.statusMessage {
                Section {
                    Text(status)
                        .foregroundStyle(viewModel.statusIsError ? .red : .secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Flight Setup")
        .alert("Apply to Aerofly?", isPresented: $viewModel.showApplyConfirmation) {
            Button("Weather only") { viewModel.applyToAerofly(includeWeather: true, includeRoute: false) }
            Button("Route only") { viewModel.applyToAerofly(includeWeather: false, includeRoute: true) }
            Button("Weather + route", role: .destructive) {
                viewModel.applyToAerofly(includeWeather: true, includeRoute: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Quit Aerofly FS 4 before applying. Changes are written to main.mcf and load on the next simulator launch. A backup is saved as main.mcf.bak on first write.")
        }
    }

    private var aircraftSection: some View {
        Section("Aircraft") {
            LabeledContent("Current") {
                Text(viewModel.aircraftLabel)
            }
            LabeledContent("Session route") {
                Text("\(viewModel.departureCode) → \(viewModel.destinationCode)")
            }
        }
    }

    private var flightPlanSection: some View {
        Section("Flight plan") {
            LabeledContent("OFP") { Text(viewModel.ofpAirports) }
            LabeledContent("Cruise") { Text(viewModel.cruiseSummary) }
            LabeledContent("Route") {
                Text(viewModel.ofpRouteSummary)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(4)
            }
        }
    }

    private var weatherSection: some View {
        Section("Weather") {
            HStack {
                TextField("ICAO", text: $viewModel.metarICAO)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Button("Fetch METAR") {
                    Task { await viewModel.fetchMETARForEditor() }
                }
                .disabled(viewModel.isWeatherFetching)
                Button("DEPT") {
                    Task { await viewModel.fetchMETAR(icao: viewModel.departureCode) }
                }
                .disabled(viewModel.departureCode == "—")
                Button("DEST") {
                    Task { await viewModel.fetchMETAR(icao: viewModel.destinationCode) }
                }
                .disabled(viewModel.destinationCode == "—")
                Spacer()
                Text(viewModel.flightCategoryLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            if let raw = viewModel.latestMETARText {
                Text(raw)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }

            weatherEditors
        }
    }

    private var weatherEditors: some View {
        Group {
            HStack {
                Text("Wind")
                Spacer()
                TextField("Dir", value: $viewModel.windDirection, format: .number)
                    .frame(width: 56)
                Text("°")
                TextField("Spd", value: $viewModel.windSpeedKnots, format: .number)
                    .frame(width: 56)
                Text("kt")
                TextField("Gst", value: $viewModel.windGustKnots, format: .number)
                    .frame(width: 56)
                Text("kt")
            }
            HStack {
                Text("Temperature")
                Spacer()
                TextField("°C", value: $viewModel.temperatureCelsius, format: .number)
                    .frame(width: 64)
                Text("°C")
            }
            HStack {
                Text("Visibility")
                Spacer()
                TextField("SM", value: $viewModel.visibilitySM, format: .number)
                    .frame(width: 64)
                Text("SM")
            }
            cloudRow("Cloud 1", cover: $viewModel.cloud1Cover, height: $viewModel.cloud1HeightFeet)
            cloudRow("Cloud 2", cover: $viewModel.cloud2Cover, height: $viewModel.cloud2HeightFeet)
            cloudRow("Cloud 3", cover: $viewModel.cloud3Cover, height: $viewModel.cloud3HeightFeet)
        }
    }

    private func cloudRow(_ title: String, cover: Binding<Double>, height: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Cover", value: cover, format: .number)
                .frame(width: 56)
            Text("×")
            TextField("ft", value: height, format: .number)
                .frame(width: 72)
            Text("ft AGL")
        }
    }

    private var importExportSection: some View {
        Section("Import / export") {
            TextField(
                "SimBrief username",
                text: Binding(
                    get: { viewModel.simBriefPreferences.username },
                    set: { viewModel.simBriefPreferences.username = $0 }
                )
            )
                .textFieldStyle(.roundedBorder)
            Picker(
                "Weather on SimBrief import",
                selection: Binding(
                    get: { viewModel.simBriefPreferences.weatherOnImport },
                    set: { viewModel.simBriefPreferences.weatherOnImport = $0 }
                )
            ) {
                ForEach(SimBriefWeatherOnImport.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            HStack {
                Button("Fetch SimBrief") {
                    Task { await viewModel.fetchSimBrief() }
                }
                .disabled(viewModel.simBriefPreferences.username.isEmpty || viewModel.isSimBriefBusy)
                Button("Import PLN…") { viewModel.importPLN() }
                Spacer()
                Button("Apply to Aerofly…") { viewModel.confirmApply() }
                    .keyboardShortcut(.defaultAction)
            }
            Text("Aerofly must be quit before Apply. Parking, runways, and SID/STAR still need finishing in Aerofly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
