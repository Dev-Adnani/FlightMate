//
//  ProcedureServiceTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct ProcedureServiceTests {

    @Test func loadsAircraftAndProceduresFromLoader() {
        let service = ProcedureService(loader: ProcedureFixtures.makeLoader())

        #expect(service.allAircraft().map(\.id) == ["a320_neo"])
        #expect(service.aircraft(id: "a320_neo")?.name == "Airbus A320neo")
        #expect(service.procedures(for: "a320_neo").map(\.id) == ["cold_and_dark"])
        #expect(service.procedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")?.title == "Cold & Dark Startup")
    }

    @Test func unknownAircraftReturnsNilAndEmpty() {
        let service = ProcedureService(loader: ProcedureFixtures.makeLoader())

        #expect(service.aircraft(id: "c172") == nil)
        #expect(service.procedures(for: "c172").isEmpty)
        #expect(service.procedure(aircraftId: "c172", procedureId: "cold_and_dark") == nil)
    }

    @Test func failedIndexYieldsEmptyService() {
        struct LoadFailure: Error {}
        let service = ProcedureService(
            loader: FakeKnowledgeDataLoader(indexError: LoadFailure())
        )

        #expect(service.allAircraft().isEmpty)
    }

    @Test func procedureFlattensStepsInOrder() {
        let procedure = ProcedureFixtures.coldAndDark

        #expect(procedure.totalStepCount == 3)
        #expect(procedure.allStepsInOrder.map(\.id) == ["bat_1", "bat_2", "apu_start"])
    }
}

struct ProcedureDecodingTests {

    @Test func decodesBundledA320ColdAndDark() throws {
        let loader = KnowledgeDataLoader(bundle: .main)
        let index = try loader.loadProcedureAircraftIndex()
        #expect(index.contains("a320_neo"))

        let aircraft = try loader.loadProcedureAircraft(id: "a320_neo")
        #expect(aircraft.id == "a320_neo")
        #expect(aircraft.supportedProcedures.contains("cold_and_dark"))

        let procedure = try loader.loadProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        #expect(procedure.id == "cold_and_dark")
        #expect(procedure.aircraft == "a320_neo")
        #expect(procedure.fidelity == .aeroflyVerified)
        #expect(procedure.totalStepCount > 20)
        #expect(procedure.sections.contains(where: { $0.id == "power_on" }))
        #expect(procedure.allStepsInOrder.first?.purpose.isEmpty == false)
    }

    @Test func decodesStepWithCondition() throws {
        let procedure = try KnowledgeDataLoader(bundle: .main)
            .loadProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        let extPower = procedure.allStepsInOrder.first { $0.id == "external_power" }
        #expect(extPower?.condition != nil)
        #expect(extPower?.verification.mode == .manual)
    }
}
