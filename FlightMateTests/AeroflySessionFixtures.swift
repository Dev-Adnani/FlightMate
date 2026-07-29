//
//  AeroflySessionFixtures.swift
//  FlightMateTests
//
//  Shared synthetic `main.mcf`/`tm.log` fixtures and fakes for testing the
//  Aerofly session pipeline (parser, mapper, service) without touching real
//  disk or timing.
//

import Foundation
@testable import FlightMate

enum AeroflySessionFixtures {
    /// A synthetic `main.mcf`, structurally modeled on a real file (same
    /// group/key names, minified body). No indentation dependency, since
    /// `AeroflyMcfParser` doesn't rely on it.
    static func mainMcf(
        aircraft: String = "a350_1000",
        livery: String = "qatar_oneworld",
        positionVector: String = "1779406.9660508 5760810.88028256 2074061.68167588",
        onGround: Bool = false,
        airport: String = "VABB",
        runway: String = "32",
        timeYear: Int = 2022,
        timeMonth: Int = 8,
        timeDay: Int = 15,
        timeHours: Double = 0.96597013890215,
        windStrength: Double = 0.2,
        windDirection: Double = 3.8584785111249e-16,
        turbulence: Double = 0.1,
        cumulusDensity: Double = 0.2,
        cumulusHeight: Double = 0.508,
        includeFlightPlan: Bool = false,
        destinationAirport: String = "EGPH",
        destinationRunway: String = "24"
    ) -> String {
        let waysBody = includeFlightPlan ? """
                    <[tmnav_route_origin][EGGP][0]
                        <[string8u][Identifier][EGGP]>
                    >
                    <[tmnav_route_departure_runway][27][1]
                        <[string8u][Identifier][27]>
                    >
                    <[tmnav_route_destination_runway][\(destinationRunway)][6]
                        <[string8u][Identifier][\(destinationRunway)]>
                    >
                    <[tmnav_route_destination][\(destinationAirport)][7]
                        <[string8u][Identifier][\(destinationAirport)]>
                    >
        """ : ""

        return """
        <[file][][]
            <[tmsettings_sim][][]
                <[tmsettings_aircraft][aircraft][]
                    <[string8u][name][\(aircraft)]>
                    <[string8u][paintscheme][\(livery)]>
                >
                <[tmsettings_flight][flight_setting][]
                    <[vector3_float64][position][\(positionVector)]>
                    <[bool][on_ground][\(onGround)]>
                    <[string8u][airport][\(airport)]>
                    <[string8u][runway][\(runway)]>
                >
                <[tm_time_utc][time_utc][]
                    <[int32][time_year][\(timeYear)]>
                    <[int32][time_month][\(timeMonth)]>
                    <[int32][time_day][\(timeDay)]>
                    <[float64][time_hours][\(timeHours)]>
                >
                <[tmsettings_wind][wind][]
                    <[float64][strength][\(windStrength)]>
                    <[float64][direction_in_degree][\(windDirection)]>
                    <[float64][turbulence][\(turbulence)]>
                >
                <[tmsettings_clouds][clouds][]
                    <[float64][cumulus_density][\(cumulusDensity)]>
                    <[float64][cumulus_height][\(cumulusHeight)]>
                >
                <[tmnavigation_config][navigation][]
                    <[tmnav_route][Route][]
                        <[pointer_list_tmnav_route_way][Ways][]
        \(waysBody)
                        >
                    >
                >
            >
        >
        """
    }

    /// A `tm.log` excerpt shaped like the real file: timestamped lines with
    /// a single `Program version` entry near the top.
    static let tmLogWithVersion = """
    [2026-07-27 17:22:10.123]        0.00-tmengine:                created
    [2026-07-27 17:22:10.124]        0.01-tmview:                  Program version 4.08.04.01
    [2026-07-27 17:22:10.130]        0.02-tmview:                  something else entirely
    """

    static let tmLogWithoutVersion = """
    [2026-07-27 17:22:10.123]        0.00-tmengine:                created
    [2026-07-27 17:22:10.130]        0.02-tmview:                  something else entirely
    """
}

// MARK: - Fakes

/// A configurable `AeroflyUserDirectoryLocating` fake — never touches real
/// disk paths.
final class FakeAeroflyUserDirectoryLocator: AeroflyUserDirectoryLocating {
    var directoryToReturn: URL?

    init(directoryToReturn: URL? = URL(fileURLWithPath: "/fake/Aerofly FS 4", isDirectory: true)) {
        self.directoryToReturn = directoryToReturn
    }

    func locateUserDirectory() -> URL? { directoryToReturn }
}

/// A controllable `AeroflyFileWatching` fake. `simulateChange()` lets tests
/// deterministically trigger the reparse path `AeroflySessionService`
/// registers via `startWatching(_:onChange:)`, without any real filesystem
/// timing.
final class FakeAeroflyFileWatching: AeroflyFileWatching {
    private(set) var watchedURL: URL?
    private(set) var stopCallCount = 0
    private var onChange: (() -> Void)?

    func startWatching(_ url: URL, onChange: @escaping () -> Void) {
        watchedURL = url
        self.onChange = onChange
    }

    func stopWatching() {
        stopCallCount += 1
    }

    func simulateChange() {
        onChange?()
    }
}

/// A configurable `AeroflyVersionReading` fake.
final class FakeAeroflyVersionReading: AeroflyVersionReading {
    var versionToReturn: String?

    init(versionToReturn: String? = "4.08.04.01") {
        self.versionToReturn = versionToReturn
    }

    func readVersion(in directory: URL) -> String? { versionToReturn }
}

/// A configurable `AeroflyLoadedAircraftReading` fake.
final class FakeAeroflyLoadedAircraftReading: AeroflyLoadedAircraftReading {
    var aircraftCodeToReturn: String?

    init(aircraftCodeToReturn: String? = nil) {
        self.aircraftCodeToReturn = aircraftCodeToReturn
    }

    func readLoadedAircraft(in directory: URL) -> String? { aircraftCodeToReturn }
}

/// A mutable box so tests can change what `AeroflySessionService`'s
/// injected `readFileContents` closure returns between reparses, without
/// writing to real disk.
final class MutableFileContentsBox {
    var contents: String?
    init(_ contents: String? = nil) {
        self.contents = contents
    }
}
