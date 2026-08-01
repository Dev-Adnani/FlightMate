//
//  UnitPreferenceService.swift
//  FlightMate
//
//  User-facing display unit preference (Imperial/Metric), persisted
//  across launches. Mirrors AircraftService/AirportService's pattern:
//  a small, constructor-injected, protocol-fronted service with no
//  hidden global state.
//

import Combine
import Foundation

/// Read/write access to the user's unit-system preference.
protocol UnitPreferenceProviding: AnyObject {
    var unitSystem: UnitSystem { get set }
}

/// Default `UnitPreferenceProviding` implementation, backed by
/// `UserDefaults`. `ObservableObject` (via `@Published`) so consumers that
/// need live updates -- e.g. `DashboardViewModel` -- can subscribe to
/// `$unitSystem` the same way they subscribe to any other engine.
final class UnitPreferenceService: UnitPreferenceProviding, ObservableObject {
    private static let storageKey = "com.flightmate.unitSystem"

    @Published var unitSystem: UnitSystem {
        didSet {
            guard unitSystem != oldValue else { return }
            userDefaults.set(unitSystem.rawValue, forKey: Self.storageKey)
        }
    }

    private let userDefaults: UserDefaults

    /// - Parameter userDefaults: Injected so this service can be unit
    ///   tested against an isolated suite rather than the shared one.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let storedRawValue = userDefaults.string(forKey: Self.storageKey),
           let stored = UnitSystem(rawValue: storedRawValue) {
            unitSystem = stored
        } else {
            unitSystem = .imperial
        }
    }
}
