//
//  DomainResolutionServiceTests.swift
//  FlightMateTests
//
//  Exercises DomainResolutionService against injected AircraftProviding/
//  AirportProviding/CountryResolving fakes, independent of the real app
//  bundle -- mirrors the style of AircraftServiceTests/AirportServiceTests.
//

import Testing
@testable import FlightMate

struct DomainResolutionServiceTests {

    private func makeAircraftProvider() -> AircraftService {
        AircraftService(loader: FakeReferenceDataLoader(
            aircraft: ReferenceDataFixtures.aircraft,
            aircraftLiveries: ReferenceDataFixtures.aircraftLiveries
        ))
    }

    private func makeAirportProvider() -> AirportService {
        AirportService(loader: FakeReferenceDataLoader(airports: ReferenceDataFixtures.airports))
    }

    private func makeService(
        aircraftProvider: AircraftProviding? = nil,
        airportProvider: AirportProviding? = nil,
        countryResolver: CountryResolving = UnavailableCountryResolver()
    ) -> DomainResolutionService {
        DomainResolutionService(
            aircraftProvider: aircraftProvider ?? makeAircraftProvider(),
            airportProvider: airportProvider ?? makeAirportProvider(),
            countryResolver: countryResolver
        )
    }

    // MARK: - Raw lookups

    @Test func resolveAircraftFindsKnownCode() {
        let service = makeService()
        #expect(service.resolveAircraft(aeroflyCode: "a320_neo") == ReferenceDataFixtures.a320)
    }

    @Test func resolveAircraftReturnsNilForUnknownCode() {
        let service = makeService()
        #expect(service.resolveAircraft(aeroflyCode: "does_not_exist") == nil)
    }

    @Test func resolveAirportFindsKnownICAO() {
        let service = makeService()
        #expect(service.resolveAirport(icaoCode: "AAAA") == ReferenceDataFixtures.origin)
    }

    @Test func resolveAirportReturnsNilForUnknownICAO() {
        let service = makeService()
        #expect(service.resolveAirport(icaoCode: "ZZZZ") == nil)
    }

    // MARK: - Aircraft selection resolution

    @Test func resolveSelectionFullyResolvesKnownAircraftAndLivery() {
        let service = makeService()
        let selection = AeroflySession.AircraftSelection(aeroflyCode: "a320_neo", liveryCode: "lufthansa")

        let resolved = service.resolve(selection)

        #expect(resolved.aircraft == ReferenceDataFixtures.a320)
        #expect(resolved.livery == ReferenceDataFixtures.lufthansaLivery)
        #expect(resolved.category == .airliner)
        #expect(resolved.status == .resolved)
    }

    @Test func resolveSelectionIsPartialWhenLiveryUnknown() {
        let service = makeService()
        let selection = AeroflySession.AircraftSelection(aeroflyCode: "a320_neo", liveryCode: "does_not_exist")

        let resolved = service.resolve(selection)

        #expect(resolved.aircraft == ReferenceDataFixtures.a320)
        #expect(resolved.livery == nil)
        #expect(resolved.status == .partial)
    }

    @Test func resolveSelectionIsResolvedWhenLiveryCodeIsEmpty() {
        // An empty paint-scheme code (nothing recorded in main.mcf) is not
        // a lookup failure -- there was nothing to look up.
        let service = makeService()
        let selection = AeroflySession.AircraftSelection(aeroflyCode: "a320_neo", liveryCode: "")

        let resolved = service.resolve(selection)

        #expect(resolved.livery == nil)
        #expect(resolved.status == .resolved)
    }

    @Test func resolveSelectionIsUnresolvedWhenAircraftUnknown() {
        let service = makeService()
        let selection = AeroflySession.AircraftSelection(aeroflyCode: "does_not_exist", liveryCode: "lufthansa")

        let resolved = service.resolve(selection)

        #expect(resolved.aircraft == nil)
        #expect(resolved.livery == nil)
        #expect(resolved.category == nil)
        #expect(resolved.status == .unresolved)
    }

    // MARK: - Runway reference resolution

    @Test func resolveReferenceResolvesKnownAirport() {
        let service = makeService()
        let reference = AeroflySession.RunwayReference(airportCode: "AAAA", runwayIdentifier: "09L")

        let resolved = service.resolve(reference)

        #expect(resolved.airport == ReferenceDataFixtures.origin)
        #expect(resolved.status == .resolved)
        #expect(resolved.runway == nil) // No runway-level data bundled today.
        #expect(resolved.country == nil) // No country dataset bundled today.
    }

    @Test func resolveReferenceIsUnresolvedForUnknownAirport() {
        let service = makeService()
        let reference = AeroflySession.RunwayReference(airportCode: "ZZZZ", runwayIdentifier: nil)

        let resolved = service.resolve(reference)

        #expect(resolved.airport == nil)
        #expect(resolved.status == .unresolved)
    }

    @Test func resolveRunwayFindsMatchWhenBundledDataHasRunways() {
        // Proves the matching logic itself works, even though every real
        // bundled Airport has an empty `runways` array today.
        let runway = Runway(identifier: "09L/27R", headingDegrees: 90, lengthFt: 10_000, widthFt: 150, surface: "asphalt")
        let airportWithRunway = Airport(
            icaoCode: "DDDD",
            name: "Runway Test Field",
            latitude: 5,
            longitude: 5,
            runways: [runway]
        )
        let airportProvider = AirportService(loader: FakeReferenceDataLoader(airports: [airportWithRunway]))
        let service = makeService(airportProvider: airportProvider)

        #expect(service.resolveRunway(icaoCode: "DDDD", identifier: "09L/27R") == runway)
        #expect(service.resolveRunway(icaoCode: "DDDD", identifier: "not_a_runway") == nil)
    }

    // MARK: - Country

    @Test func unavailableCountryResolverAlwaysReturnsNil() {
        let resolver = UnavailableCountryResolver()
        #expect(resolver.resolveCountry(forICAO: "VABB") == nil)
        #expect(resolver.resolveCountry(forICAO: "KSFO") == nil)
    }

    // MARK: - Full session resolution

    @Test func resolveSessionResolvesAircraftAndDepartureWithNoDestination() {
        let service = makeService()
        var session = AeroflySession()
        session.aircraft = AeroflySession.AircraftSelection(aeroflyCode: "a320_neo", liveryCode: "lufthansa")
        session.departure = AeroflySession.RunwayReference(airportCode: "AAAA", runwayIdentifier: "09L")
        session.destination = nil

        let (resolved, report) = service.resolve(session)

        #expect(resolved.aircraft?.status == .resolved)
        #expect(resolved.departure?.status == .resolved)
        #expect(resolved.destination == nil)

        #expect(report.entries.contains(DomainResolutionEntry(field: "aircraft", status: .resolved, detail: nil)))
        #expect(report.entries.contains(DomainResolutionEntry(field: "livery", status: .resolved, detail: nil)))
        #expect(report.entries.contains(DomainResolutionEntry(field: "departureAirport", status: .resolved, detail: nil)))
        #expect(report.informational.contains { $0.field == "departureRunway" })
        #expect(report.informational.contains { $0.field == "departureCountry" })

        // No destination in the session (no flight plan set) is a real,
        // if expected, warning -- not swallowed into `.unavailable`.
        #expect(report.hasWarnings)
        #expect(report.warnings.contains { $0.field == "destinationAirport" && $0.detail == "no flight plan set" })
        #expect(!report.warnings.contains { $0.field == "aircraft" })
        #expect(!report.warnings.contains { $0.field == "livery" })
        #expect(!report.warnings.contains { $0.field == "departureAirport" })
    }

    @Test func resolveSessionResolvesDestinationWhenPresent() {
        let service = makeService()
        var session = AeroflySession()
        session.departure = AeroflySession.RunwayReference(airportCode: "AAAA", runwayIdentifier: nil)
        session.destination = AeroflySession.RunwayReference(airportCode: "BBBB", runwayIdentifier: nil)

        let (resolved, _) = service.resolve(session)

        #expect(resolved.destination?.airport == ReferenceDataFixtures.oneDegreeEast)
        #expect(resolved.destination?.status == .resolved)
    }

    @Test func resolveSessionReportsMissingAircraftAndUnknownAirports() {
        let service = makeService()
        var session = AeroflySession()
        session.aircraft = nil
        session.departure = AeroflySession.RunwayReference(airportCode: "ZZZZ", runwayIdentifier: nil)

        let (resolved, report) = service.resolve(session)

        #expect(resolved.aircraft == nil)
        #expect(resolved.departure?.status == .unresolved)
        #expect(report.warnings.contains { $0.field == "aircraft" })
        #expect(report.warnings.contains { $0.field == "departureAirport" })
    }

    // MARK: - Caching

    @Test func resolveAircraftIsMemoized() {
        let countingProvider = CountingAircraftProvider(base: makeAircraftProvider())
        let service = makeService(aircraftProvider: countingProvider)

        _ = service.resolveAircraft(aeroflyCode: "a320_neo")
        _ = service.resolveAircraft(aeroflyCode: "a320_neo")
        _ = service.resolveAircraft(aeroflyCode: "a320_neo")

        #expect(countingProvider.aircraftLookupCount == 1)
    }

    @Test func resolveAircraftCachesMissesToo() {
        let countingProvider = CountingAircraftProvider(base: makeAircraftProvider())
        let service = makeService(aircraftProvider: countingProvider)

        _ = service.resolveAircraft(aeroflyCode: "does_not_exist")
        _ = service.resolveAircraft(aeroflyCode: "does_not_exist")

        #expect(countingProvider.aircraftLookupCount == 1)
    }

    @Test func resolveAirportIsMemoized() {
        let countingProvider = CountingAirportProvider(base: makeAirportProvider())
        let service = makeService(airportProvider: countingProvider)

        _ = service.resolveAirport(icaoCode: "AAAA")
        _ = service.resolveAirport(icaoCode: "AAAA")

        #expect(countingProvider.airportLookupCount == 1)
    }

    @Test func resolveAirportCachesMissesToo() {
        let countingProvider = CountingAirportProvider(base: makeAirportProvider())
        let service = makeService(airportProvider: countingProvider)

        _ = service.resolveAirport(icaoCode: "ZZZZ")
        _ = service.resolveAirport(icaoCode: "ZZZZ")

        #expect(countingProvider.airportLookupCount == 1)
    }
}
