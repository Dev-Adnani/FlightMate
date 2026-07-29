//
//  AeroflySessionMapper.swift
//  FlightMate
//
//  Pure mapping from a parsed main.mcf tree into a typed AeroflySession,
//  producing a developer-facing validation report alongside it. All
//  "which group/key holds what" domain knowledge for main.mcf lives here
//  and nowhere else.
//
//  Structural groups (tmsettings_aircraft, tmsettings_flight, ...) are
//  looked up by `type` (a stable namespace); individual leaf fields within
//  them are looked up by `key`. See AeroflyMcfNode's doc comments.
//

import Foundation

enum AeroflySessionMapper {
    /// Maps a parsed `main.mcf` root node (+ a separately-read Aerofly
    /// version, since it comes from `tm.log`, not `main.mcf`) into an
    /// `AeroflySession` and its validation report.
    static func map(
        _ root: AeroflyMcfNode,
        aeroflyVersion: String?,
        now: @escaping () -> Date = Date.init
    ) -> (session: AeroflySession, report: AeroflySessionValidationReport) {
        var session = AeroflySession()
        var entries: [AeroflySessionValidationEntry] = []

        guard let sim = root.firstChild(type: "tmsettings_sim") else {
            entries.append(AeroflySessionValidationEntry(
                field: "root",
                status: .unexpected,
                detail: "tmsettings_sim group not found under root"
            ))
            mapVersion(aeroflyVersion, into: &session, entries: &entries)
            return (session, AeroflySessionValidationReport(entries: entries, generatedAt: now()))
        }

        mapAircraft(sim, into: &session, entries: &entries)
        mapFlightSetting(sim, into: &session, entries: &entries)
        mapTime(sim, into: &session, entries: &entries)
        mapWeather(sim, into: &session, entries: &entries)
        mapDestination(sim, into: &session, entries: &entries)
        mapVersion(aeroflyVersion, into: &session, entries: &entries)

        return (session, AeroflySessionValidationReport(entries: entries, generatedAt: now()))
    }

    // MARK: - Aircraft

    private static func mapAircraft(
        _ sim: AeroflyMcfNode,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        // Current selection is keyed `aircraft` (`<[tmsettings_aircraft][aircraft][]>`).
        // Do NOT use `firstChild(type:)` alone — `aircraft_list` also contains
        // nested `tmsettings_aircraft` elements (recent planes, often including
        // the default Cessna c172) that must never be treated as the live plane.
        let aircraftNode =
            sim.children.first { $0.key == "aircraft" && $0.type == "tmsettings_aircraft" }
            ?? sim.firstChild(type: "tmsettings_aircraft")

        if let aircraftNode,
           let name = aircraftNode.firstChild(key: "name")?.value,
           !name.isEmpty {
            let liveryCode = aircraftNode.firstChild(key: "paintscheme")?.value ?? ""
            session.aircraft = AeroflySession.AircraftSelection(aeroflyCode: name, liveryCode: liveryCode)
            entries.append(AeroflySessionValidationEntry(field: "aircraft", status: .found, detail: "\(name) / \(liveryCode)"))
            return
        }

        // Secondary signal inside main.mcf: fuel/payload block mirrors the
        // selected aircraft code even when the primary group is malformed.
        if let fuelNode = sim.firstChild(type: "tmsettings_fuel_load")
            ?? sim.firstChild(key: "fuel_load_setting"),
           let name = fuelNode.firstChild(key: "aircraft")?.value,
           !name.isEmpty {
            session.aircraft = AeroflySession.AircraftSelection(aeroflyCode: name, liveryCode: "")
            entries.append(AeroflySessionValidationEntry(
                field: "aircraft",
                status: .found,
                detail: "\(name) (from fuel_load_setting)"
            ))
            return
        }

        entries.append(AeroflySessionValidationEntry(
            field: "aircraft",
            status: aircraftNode == nil ? .missing : .unexpected,
            detail: aircraftNode == nil
                ? "tmsettings_aircraft[aircraft] group not found"
                : "missing or empty 'name' leaf"
        ))
    }

    // MARK: - Flight setting (position, on_ground, departure)

    private static func mapFlightSetting(
        _ sim: AeroflyMcfNode,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        guard let flightNode = sim.firstChild(type: "tmsettings_flight") else {
            entries.append(AeroflySessionValidationEntry(field: "initialPosition", status: .missing, detail: "tmsettings_flight group not found"))
            entries.append(AeroflySessionValidationEntry(field: "onGround", status: .missing, detail: "tmsettings_flight group not found"))
            entries.append(AeroflySessionValidationEntry(field: "departure", status: .missing, detail: "tmsettings_flight group not found"))
            return
        }

        if let positionNode = flightNode.firstChild(key: "position") {
            let vector = positionNode.doubleArray
            if let coordinate = AeroflyPositionConverter.coordinate(fromPosition: vector) {
                session.initialPosition = coordinate
                entries.append(AeroflySessionValidationEntry(field: "initialPosition", status: .found, detail: nil))
            } else {
                entries.append(AeroflySessionValidationEntry(field: "initialPosition", status: .unexpected, detail: "position vector had \(vector.count) components, expected 3"))
            }
        } else {
            entries.append(AeroflySessionValidationEntry(field: "initialPosition", status: .missing, detail: nil))
        }

        if let onGround = flightNode.firstChild(key: "on_ground")?.boolValue {
            session.onGround = onGround
            entries.append(AeroflySessionValidationEntry(field: "onGround", status: .found, detail: nil))
        } else {
            entries.append(AeroflySessionValidationEntry(field: "onGround", status: .missing, detail: nil))
        }

        if let airportCode = flightNode.firstChild(key: "airport")?.value, !airportCode.isEmpty {
            let runway = flightNode.firstChild(key: "runway")?.value
            session.departure = AeroflySession.RunwayReference(
                airportCode: airportCode,
                runwayIdentifier: (runway?.isEmpty == false) ? runway : nil
            )
            entries.append(AeroflySessionValidationEntry(field: "departure", status: .found, detail: airportCode))
        } else {
            entries.append(AeroflySessionValidationEntry(field: "departure", status: .missing, detail: nil))
        }
    }

    // MARK: - Simulated time

    private static func mapTime(
        _ sim: AeroflyMcfNode,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        guard let timeNode = sim.firstChild(type: "tm_time_utc") else {
            entries.append(AeroflySessionValidationEntry(field: "simulatedTime", status: .missing, detail: "tm_time_utc group not found"))
            return
        }

        let year = timeNode.firstChild(key: "time_year")?.intValue
        let month = timeNode.firstChild(key: "time_month")?.intValue
        let day = timeNode.firstChild(key: "time_day")?.intValue
        let hours = timeNode.firstChild(key: "time_hours")?.doubleValue

        session.simulatedTime = AeroflySession.SimulatedTime(year: year, month: month, day: day, hours: hours)

        if year != nil || month != nil || day != nil || hours != nil {
            entries.append(AeroflySessionValidationEntry(field: "simulatedTime", status: .found, detail: nil))
        } else {
            entries.append(AeroflySessionValidationEntry(field: "simulatedTime", status: .unexpected, detail: "tm_time_utc present but no recognized fields"))
        }
    }

    // MARK: - Weather (wind + clouds)

    private static func mapWeather(
        _ sim: AeroflyMcfNode,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        let windNode = sim.firstChild(type: "tmsettings_wind")
        let cloudsNode = sim.firstChild(type: "tmsettings_clouds")

        entries.append(AeroflySessionValidationEntry(
            field: "weather.wind",
            status: windNode == nil ? .missing : .found,
            detail: windNode == nil ? "tmsettings_wind group not found" : nil
        ))
        entries.append(AeroflySessionValidationEntry(
            field: "weather.clouds",
            status: cloudsNode == nil ? .missing : .found,
            detail: cloudsNode == nil ? "tmsettings_clouds group not found" : nil
        ))

        guard windNode != nil || cloudsNode != nil else { return }

        session.weather = AeroflySession.WeatherConditions(
            windStrengthFraction: windNode?.firstChild(key: "strength")?.doubleValue,
            windDirectionDegrees: windNode?.firstChild(key: "direction_in_degree")?.doubleValue,
            turbulenceFraction: windNode?.firstChild(key: "turbulence")?.doubleValue,
            cumulusDensityFraction: cloudsNode?.firstChild(key: "cumulus_density")?.doubleValue,
            cumulusHeightFraction: cloudsNode?.firstChild(key: "cumulus_height")?.doubleValue
        )
    }

    // MARK: - Destination (best-effort, from navigation.Route.Ways)

    private static func mapDestination(
        _ sim: AeroflyMcfNode,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        guard
            let navigationNode = sim.firstChild(type: "tmnavigation_config"),
            let routeNode = navigationNode.firstChild(type: "tmnav_route"),
            let waysNode = routeNode.firstChild(type: "pointer_list_tmnav_route_way")
        else {
            entries.append(AeroflySessionValidationEntry(field: "destination", status: .missing, detail: "navigation/Route/Ways group not found"))
            return
        }

        // Each waypoint's node `key` is the waypoint identifier itself
        // (e.g. "KMIA", "08L"), and `type` (prefixed "tmnav_route_")
        // identifies its role in the route. Confirmed against a real
        // main.mcf with a flight plan set.
        guard let destinationNode = waysNode.firstChild(type: "tmnav_route_destination"), !destinationNode.key.isEmpty else {
            entries.append(AeroflySessionValidationEntry(field: "destination", status: .missing, detail: "no flight plan set"))
            return
        }

        let destinationRunwayNode = waysNode.firstChild(type: "tmnav_route_destination_runway")
        session.destination = AeroflySession.RunwayReference(
            airportCode: destinationNode.key,
            runwayIdentifier: (destinationRunwayNode?.key.isEmpty == false) ? destinationRunwayNode?.key : nil
        )
        entries.append(AeroflySessionValidationEntry(field: "destination", status: .found, detail: destinationNode.key))
    }

    // MARK: - Version (from tm.log, not main.mcf)

    private static func mapVersion(
        _ aeroflyVersion: String?,
        into session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        session.aeroflyVersion = aeroflyVersion
        if let aeroflyVersion {
            entries.append(AeroflySessionValidationEntry(field: "aeroflyVersion", status: .found, detail: aeroflyVersion))
        } else {
            entries.append(AeroflySessionValidationEntry(field: "aeroflyVersion", status: .missing, detail: "tm.log not found or unreadable"))
        }
    }
}
