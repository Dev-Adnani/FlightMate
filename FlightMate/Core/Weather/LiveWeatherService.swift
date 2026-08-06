//
//  LiveWeatherService.swift
//  FlightMate
//
//  Fetches live METAR for session airports and publishes editable weather.
//

import Combine
import Foundation

protocol LiveWeatherProviding: AnyObject {
    var latestMETAR: METARObservation? { get }
    var editableWeather: AeroflyEditableWeather? { get }
    var lastErrorMessage: String? { get }
    func fetchMETAR(forICAO icao: String) async
}

@MainActor
final class LiveWeatherService: ObservableObject, LiveWeatherProviding {
    @Published private(set) var latestMETAR: METARObservation?
    @Published private(set) var editableWeather: AeroflyEditableWeather?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isFetching = false

    private let fetcher: METARFetching

    init(fetcher: METARFetching = AviationWeatherClient()) {
        self.fetcher = fetcher
    }

    func fetchMETAR(forICAO icao: String) async {
        let code = icao.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            lastErrorMessage = "Enter an ICAO airport code."
            return
        }
        isFetching = true
        lastErrorMessage = nil
        defer { isFetching = false }
        do {
            let results = try await fetcher.fetchMETAR(icaoIds: [code])
            guard let first = results.first else {
                lastErrorMessage = "No METAR found for \(code)."
                return
            }
            latestMETAR = first
            editableWeather = AeroflyEditableWeather.from(metar: first)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func applyEditableWeather(_ weather: AeroflyEditableWeather) {
        editableWeather = weather
    }
}
