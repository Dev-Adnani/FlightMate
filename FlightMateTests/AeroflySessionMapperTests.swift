//
//  AeroflySessionMapperTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct AeroflySessionMapperTests {
    private func mappedSession(
        includeFlightPlan: Bool = false,
        aeroflyVersion: String? = "4.08.04.01"
    ) throws -> (session: AeroflySession, report: AeroflySessionValidationReport) {
        let text = AeroflySessionFixtures.mainMcf(includeFlightPlan: includeFlightPlan)
        let root = try AeroflyMcfParser.parse(text)
        return AeroflySessionMapper.map(root, aeroflyVersion: aeroflyVersion)
    }

    @Test func mapsAircraftAndLivery() throws {
        let (session, report) = try mappedSession()
        #expect(session.aircraft?.aeroflyCode == "a350_1000")
        #expect(session.aircraft?.liveryCode == "qatar_oneworld")
        #expect(report.entries.contains { $0.field == "aircraft" && $0.status == .found })
    }

    @Test func prefersCurrentAircraftKeyOverAircraftListCessna() throws {
        // Regression: aircraft_list often still contains c172 (Aerofly default).
        // Live selection must come from key `aircraft`, never list elements.
        let text = """
        <[file][][]
            <[tmsettings_sim][][]
                <[tmsettings_aircraft][aircraft][]
                    <[string8u][name][a320_neo]>
                    <[string8u][paintscheme][]>
                >
                <[list_tmsettings_aircraft][aircraft_list][]
                    <[tmsettings_aircraft][element][0]
                        <[string8u][name][c172]>
                        <[string8u][paintscheme][classic]>
                    >
                >
            >
        >
        """
        let root = try AeroflyMcfParser.parse(text)
        let (session, _) = AeroflySessionMapper.map(root, aeroflyVersion: nil)
        #expect(session.aircraft?.aeroflyCode == "a320_neo")
    }

    @Test func fallsBackToFuelLoadAircraftWhenPrimaryGroupMissing() throws {
        let text = """
        <[file][][]
            <[tmsettings_sim][][]
                <[tmsettings_fuel_load][fuel_load_setting][]
                    <[string8u][aircraft][a320_neo]>
                    <[float64][fuel_mass][7800]>
                >
            >
        >
        """
        let root = try AeroflyMcfParser.parse(text)
        let (session, report) = AeroflySessionMapper.map(root, aeroflyVersion: nil)
        #expect(session.aircraft?.aeroflyCode == "a320_neo")
        #expect(report.entries.contains {
            $0.field == "aircraft" && ($0.detail?.contains("fuel_load_setting") ?? false)
        })
    }

    @Test func mapsInitialPositionFromPositionVector() throws {
        let (session, _) = try mappedSession()
        let position = try #require(session.initialPosition)
        #expect(abs(position.latitude - 19.09) < 0.1)
        #expect(abs(position.longitude - 72.87) < 0.1)
    }

    @Test func mapsOnGroundAndDeparture() throws {
        let (session, _) = try mappedSession()
        #expect(session.onGround == false)
        #expect(session.departure?.airportCode == "VABB")
        #expect(session.departure?.runwayIdentifier == "32")
    }

    @Test func mapsWeatherAndSimulatedTime() throws {
        let (session, _) = try mappedSession()
        #expect(session.weather?.windStrengthFraction == 0.2)
        #expect(session.weather?.turbulenceFraction == 0.1)
        #expect(session.weather?.cumulusDensityFraction == 0.2)
        #expect(session.simulatedTime?.year == 2022)
        #expect(session.simulatedTime?.month == 8)
        #expect(session.simulatedTime?.day == 15)
    }

    @Test func destinationIsNilWithEmptyRouteWays() throws {
        let (session, report) = try mappedSession(includeFlightPlan: false)
        #expect(session.destination == nil)
        let entry = try #require(report.entries.first { $0.field == "destination" })
        #expect(entry.status == .missing)
        #expect(entry.detail == "no flight plan set")
    }

    @Test func destinationIsPopulatedWithFlightPlan() throws {
        let (session, report) = try mappedSession(includeFlightPlan: true)
        #expect(session.destination?.airportCode == "EGPH")
        #expect(session.destination?.runwayIdentifier == "24")
        #expect(report.entries.contains { $0.field == "destination" && $0.status == .found })
    }

    @Test func versionIsMappedWhenProvided() throws {
        let (session, report) = try mappedSession(aeroflyVersion: "4.08.04.01")
        #expect(session.aeroflyVersion == "4.08.04.01")
        #expect(report.entries.contains { $0.field == "aeroflyVersion" && $0.status == .found })
    }

    @Test func versionMissingIsReportedAsMissingNotUnexpected() throws {
        let (session, report) = try mappedSession(aeroflyVersion: nil)
        #expect(session.aeroflyVersion == nil)
        let entry = try #require(report.entries.first { $0.field == "aeroflyVersion" })
        #expect(entry.status == .missing)
    }

    @Test func rootMissingTmsettingsSimProducesUnexpectedEntryAndEmptySession() throws {
        let root = try AeroflyMcfParser.parse("<[file][][]\n<[something_else][][]>\n>")
        let (session, report) = AeroflySessionMapper.map(root, aeroflyVersion: nil)

        #expect(session.aircraft == nil)
        #expect(session.departure == nil)
        #expect(report.entries.contains { $0.field == "root" && $0.status == .unexpected })
    }

    @Test func reportHasNoWarningsForACleanFullFixture() throws {
        let (_, report) = try mappedSession(includeFlightPlan: true)
        #expect(!report.hasWarnings)
    }
}
