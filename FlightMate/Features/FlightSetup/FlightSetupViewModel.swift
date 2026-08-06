//
//  FlightSetupViewModel.swift
//  FlightMate
//
//  Orchestrates Flight Setup (Startgerät-style): session display, METAR,
//  SimBrief, and Apply to Aerofly.
//

import Combine
import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class FlightSetupViewModel: ObservableObject {
    @Published var metarICAO: String = ""
    @Published var windDirection: Double = 0
    @Published var windSpeedKnots: Double = 0
    @Published var windGustKnots: Double = 0
    @Published var temperatureCelsius: Double = 15
    @Published var visibilitySM: Double = 10
    @Published var cloud1Cover: Double = 0
    @Published var cloud1HeightFeet: Double = 0
    @Published var cloud2Cover: Double = 0
    @Published var cloud2HeightFeet: Double = 0
    @Published var cloud3Cover: Double = 0
    @Published var cloud3HeightFeet: Double = 0

    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false
    @Published var showApplyConfirmation = false
    @Published private(set) var isWeatherFetching = false
    @Published private(set) var isSimBriefBusy = false
    @Published private(set) var latestMETARText: String?

    private let flightContextEngine: FlightContextEngine
    private let flightAnalysisEngine: FlightAnalysisEngine
    let liveWeatherService: LiveWeatherService
    let simBriefService: SimBriefService
    let simBriefPreferences: SimBriefPreferenceService
    private let mcfWriter: AeroflyMcfWriting
    private var cancellables = Set<AnyCancellable>()

    init(
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine,
        liveWeatherService: LiveWeatherService,
        simBriefService: SimBriefService,
        simBriefPreferences: SimBriefPreferenceService,
        mcfWriter: AeroflyMcfWriting = AeroflyMcfWriter()
    ) {
        self.flightContextEngine = flightContextEngine
        self.flightAnalysisEngine = flightAnalysisEngine
        self.liveWeatherService = liveWeatherService
        self.simBriefService = simBriefService
        self.simBriefPreferences = simBriefPreferences
        self.mcfWriter = mcfWriter

        if let dep = flightContextEngine.context.aeroflySession?.departure?.airportCode {
            metarICAO = dep
        }

        liveWeatherService.$editableWeather
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] weather in
                self?.loadWeatherEditors(from: weather)
            }
            .store(in: &cancellables)

        liveWeatherService.$isFetching
            .receive(on: RunLoop.main)
            .assign(to: &$isWeatherFetching)

        liveWeatherService.$latestMETAR
            .receive(on: RunLoop.main)
            .map { $0?.rawText }
            .assign(to: &$latestMETARText)

        simBriefService.$isBusy
            .receive(on: RunLoop.main)
            .assign(to: &$isSimBriefBusy)

        simBriefService.$latestOFP
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        simBriefPreferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var aircraftLabel: String {
        let analysis = flightAnalysisEngine.analysis
        if let resolved = analysis.resolvedAircraft {
            let name = resolved.aircraft?.name ?? resolved.aircraftCode
            let livery = resolved.livery?.name ?? (resolved.liveryCode.isEmpty ? nil : resolved.liveryCode)
            if let livery {
                return "\(name) · \(livery)"
            }
            return name
        }
        if let code = flightContextEngine.context.aeroflySession?.aircraft?.aeroflyCode {
            return code
        }
        return "Unknown"
    }

    var departureCode: String {
        flightContextEngine.context.aeroflySession?.departure?.airportCode
            ?? flightAnalysisEngine.analysis.resolvedDeparture?.icaoCode
            ?? "—"
    }

    var destinationCode: String {
        flightContextEngine.context.aeroflySession?.destination?.airportCode
            ?? flightAnalysisEngine.analysis.resolvedDestination?.icaoCode
            ?? "—"
    }

    var ofpRouteSummary: String {
        simBriefService.latestOFP?.routeString ?? "No flight plan loaded"
    }

    var ofpAirports: String {
        guard let ofp = simBriefService.latestOFP else { return "—" }
        return ofp.distanceSummary
    }

    var cruiseSummary: String {
        guard let ofp = simBriefService.latestOFP else { return "—" }
        let alt = ofp.cruiseAltitudeFeet.map { "FL\(Int($0 / 100))" } ?? "—"
        let spd = ofp.cruiseSpeedKnots.map { String(format: "%.0f kt", $0) } ?? "—"
        return "\(alt) · \(spd)"
    }

    var flightCategoryLabel: String {
        currentEditableWeather().flightCategory.rawValue
    }

    func fetchMETARForEditor() async {
        await liveWeatherService.fetchMETAR(forICAO: metarICAO)
        if let err = liveWeatherService.lastErrorMessage {
            statusMessage = err
            statusIsError = true
        } else {
            statusMessage = "METAR loaded for \(metarICAO.uppercased())."
            statusIsError = false
        }
    }

    func fetchMETAR(icao: String) async {
        metarICAO = icao
        await fetchMETARForEditor()
    }

    func fetchSimBrief() async {
        await simBriefService.fetchLatestOFP()
        if let err = simBriefService.lastErrorMessage {
            statusMessage = err
            statusIsError = true
            return
        }
        statusMessage = "SimBrief OFP imported."
        statusIsError = false
        await applySimBriefWeatherIfNeeded()
    }

    func importPLN() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import SimBrief / MSFS PLN"
        panel.message = "Choose a .pln flight plan file."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await simBriefService.importPLN(from: url)
            if let err = simBriefService.lastErrorMessage {
                statusMessage = err
                statusIsError = true
            } else {
                statusMessage = "PLN imported."
                statusIsError = false
            }
        }
    }

    func confirmApply() {
        showApplyConfirmation = true
    }

    func applyToAerofly(includeWeather: Bool, includeRoute: Bool) {
        do {
            let weather = includeWeather ? currentEditableWeather() : nil
            let route = includeRoute ? simBriefService.latestOFP : nil
            try mcfWriter.apply(weather: weather, route: route)
            statusMessage = "Wrote main.mcf. Quit Aerofly if it was open, then launch to load the new setup. Set parking/runways/SIDs in Aerofly if needed."
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func applySimBriefWeatherIfNeeded() async {
        let mode = simBriefPreferences.weatherOnImport
        guard mode != .none, let ofp = simBriefService.latestOFP else { return }
        let icao = mode == .origin ? ofp.origin.icao : ofp.destination.icao
        metarICAO = icao
        if let raw = (mode == .origin ? ofp.origin.metarRaw : ofp.destination.metarRaw),
           !raw.isEmpty {
            // Prefer live AWC; fall back to fetching by ICAO.
        }
        await liveWeatherService.fetchMETAR(forICAO: icao)
    }

    private func loadWeatherEditors(from weather: AeroflyEditableWeather) {
        windDirection = weather.windDirectionDegrees
        windSpeedKnots = weather.windSpeedKnots
        windGustKnots = weather.windGustKnots
        temperatureCelsius = weather.temperatureCelsius
        visibilitySM = weather.visibilityStatuteMiles
        cloud1Cover = weather.clouds.indices.contains(0) ? weather.clouds[0].coverFraction : 0
        cloud1HeightFeet = weather.clouds.indices.contains(0) ? weather.clouds[0].heightFeetAGL : 0
        cloud2Cover = weather.clouds.indices.contains(1) ? weather.clouds[1].coverFraction : 0
        cloud2HeightFeet = weather.clouds.indices.contains(1) ? weather.clouds[1].heightFeetAGL : 0
        cloud3Cover = weather.clouds.indices.contains(2) ? weather.clouds[2].coverFraction : 0
        cloud3HeightFeet = weather.clouds.indices.contains(2) ? weather.clouds[2].heightFeetAGL : 0
    }

    private func currentEditableWeather() -> AeroflyEditableWeather {
        AeroflyEditableWeather(
            windDirectionDegrees: windDirection,
            windSpeedKnots: windSpeedKnots,
            windGustKnots: windGustKnots,
            temperatureCelsius: temperatureCelsius,
            visibilityStatuteMiles: visibilitySM,
            clouds: [
                .init(coverFraction: cloud1Cover, heightFeetAGL: cloud1HeightFeet),
                .init(coverFraction: cloud2Cover, heightFeetAGL: cloud2HeightFeet),
                .init(coverFraction: cloud3Cover, heightFeetAGL: cloud3HeightFeet),
            ]
        )
    }
}
