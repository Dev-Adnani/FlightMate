//
//  SimBriefPreferenceService.swift
//  FlightMate
//
//  Persists SimBrief username and weather-on-import preference.
//

import Combine
import Foundation

protocol SimBriefPreferenceProviding: AnyObject {
    var username: String { get set }
    var weatherOnImport: SimBriefWeatherOnImport { get set }
}

final class SimBriefPreferenceService: SimBriefPreferenceProviding, ObservableObject {
    private static let usernameKey = "com.flightmate.simbrief.username"
    private static let weatherKey = "com.flightmate.simbrief.weatherOnImport"

    @Published var username: String {
        didSet {
            guard username != oldValue else { return }
            userDefaults.set(username, forKey: Self.usernameKey)
        }
    }

    @Published var weatherOnImport: SimBriefWeatherOnImport {
        didSet {
            guard weatherOnImport != oldValue else { return }
            userDefaults.set(weatherOnImport.rawValue, forKey: Self.weatherKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        username = userDefaults.string(forKey: Self.usernameKey) ?? ""
        let stored = userDefaults.object(forKey: Self.weatherKey) as? Int
        weatherOnImport = SimBriefWeatherOnImport(rawValue: stored ?? 0) ?? .origin
    }
}
