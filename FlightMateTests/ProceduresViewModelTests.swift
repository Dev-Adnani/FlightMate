//
//  ProceduresViewModelTests.swift
//  FlightMateTests
//

import Testing
@testable import FlightMate

@MainActor
struct ProceduresViewModelTests {

    private func makeViewModel() -> ProceduresViewModel {
        ProceduresViewModel(procedureProvider: ProcedureService(loader: ProcedureFixtures.makeLoader()))
    }

    @Test func startsOnAircraftList() {
        let vm = makeViewModel()
        #expect(vm.screen == .aircraftList)
        #expect(vm.aircraft.count == 1)
    }

    @Test func selectProcedureOpensOverview() {
        let vm = makeViewModel()
        vm.selectAircraft("a320_neo")
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")

        #expect(vm.screen == .overview(aircraftId: "a320_neo", procedureId: "cold_and_dark"))
        #expect(vm.activeProcedure?.totalStepCount == 3)
    }

    @Test func openStepThenAdvanceReturnsToOverview() {
        let vm = makeViewModel()
        vm.selectAircraft("a320_neo")
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        vm.openStep(at: 0)

        #expect(vm.screen == .stepGuide(aircraftId: "a320_neo", procedureId: "cold_and_dark"))
        #expect(vm.currentStep?.id == "bat_1")

        vm.advance()
        #expect(vm.currentStep?.id == "bat_2")
        #expect(vm.isStepCompleted("bat_1"))

        vm.advance()
        vm.advance()
        #expect(vm.screen == .overview(aircraftId: "a320_neo", procedureId: "cold_and_dark"))
    }

    @Test func toggleStepCompletedOnOverview() {
        let vm = makeViewModel()
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        vm.toggleStepCompleted("bat_1")
        #expect(vm.isStepCompleted("bat_1"))
        vm.toggleStepCompleted("bat_1")
        #expect(!vm.isStepCompleted("bat_1"))
    }

    @Test func goBackFromFirstStepReturnsToOverview() {
        let vm = makeViewModel()
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        vm.openStep(at: 0)
        vm.goBackStep()
        #expect(vm.screen == .overview(aircraftId: "a320_neo", procedureId: "cold_and_dark"))
    }
}
