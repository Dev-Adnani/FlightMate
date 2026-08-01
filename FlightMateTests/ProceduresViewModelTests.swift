//
//  ProceduresViewModelTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

@MainActor
struct ProceduresViewModelTests {

    private func makeViewModel(
        loader: FakeKnowledgeDataLoader = ProcedureFixtures.makeLoader(),
        progressStore: ProcedureProgressStoring = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())
    ) -> ProceduresViewModel {
        let flightContextEngine = FlightContextEngine(
            telemetryService: TelemetryService(),
            aeroflySessionService: AeroflySessionService(
                directoryLocator: FakeAeroflyUserDirectoryLocator(directoryToReturn: nil),
                fileWatcher: FakeAeroflyFileWatching(),
                versionReader: FakeAeroflyVersionReading(versionToReturn: nil)
            )
        )
        return ProceduresViewModel(
            procedureProvider: ProcedureService(loader: loader),
            progressStore: progressStore,
            flightContextEngine: flightContextEngine,
            flightAnalysisEngine: FlightAnalysisEngine(flightContextEngine: flightContextEngine)
        )
    }

    /// A fresh `UserDefaults` suite per test so persisted progress from one
    /// test can never leak into another. `nonisolated` because default
    /// parameter expressions are evaluated outside the enclosing type's
    /// actor context.
    private nonisolated static func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "ProceduresViewModelTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName) ?? .standard
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

    // MARK: - Persistence

    @Test func completedProgressPersistsAcrossViewModelInstances() {
        let store = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())

        let first = makeViewModel(progressStore: store)
        first.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        first.toggleStepCompleted("bat_1")

        // A brand new view model instance (e.g. after navigating away and
        // back, or an app relaunch) sharing the same store must restore
        // progress rather than starting blank.
        let second = makeViewModel(progressStore: store)
        second.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        #expect(second.isStepCompleted("bat_1"))
    }

    @Test func advancingThroughStepsPersistsCompletion() {
        let store = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())

        let first = makeViewModel(progressStore: store)
        first.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        first.openStep(at: 0)
        first.advance()

        let second = makeViewModel(progressStore: store)
        second.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        #expect(second.isStepCompleted("bat_1"))
        #expect(!second.isStepCompleted("bat_2"))
    }

    @Test func restartProcedureClearsInMemoryAndPersistedProgress() {
        let store = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())

        let vm = makeViewModel(progressStore: store)
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        vm.toggleStepCompleted("bat_1")
        #expect(vm.isStepCompleted("bat_1"))

        vm.restartProcedure()
        #expect(!vm.isStepCompleted("bat_1"))
        #expect(vm.screen == .overview(aircraftId: "a320_neo", procedureId: "cold_and_dark"))

        // The clear must have reached the shared store too, not just this
        // instance's in-memory state.
        let another = makeViewModel(progressStore: store)
        another.selectProcedure(aircraftId: "a320_neo", procedureId: "cold_and_dark")
        #expect(!another.isStepCompleted("bat_1"))
    }

    // MARK: - Automatic verification

    @Test func automaticStepCompletesImmediatelyWhenItsConditionAlreadyHolds() {
        // Default (no telemetry received) FlightAnalysis reports `.unknown`,
        // which counts as "not airborne" -- so an `.onGround` condition is
        // satisfied the instant the procedure is opened, with no packets
        // needed.
        let vm = makeAutomaticFixtureViewModel(condition: ProcedureAutomaticCondition(kind: .onGround, value: nil, phase: nil))
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "auto_test")
        #expect(vm.isStepCompleted("auto_step"))
    }

    @Test func automaticStepStaysIncompleteWhileItsConditionIsUnmet() {
        let vm = makeAutomaticFixtureViewModel(condition: ProcedureAutomaticCondition(kind: .minAltitudeFeet, value: 1000, phase: nil))
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "auto_test")
        #expect(!vm.isStepCompleted("auto_step"))
    }

    // MARK: - Phase-aware suggestion

    @Test func suggestsTheSectionMatchingTheLiveFlightPhase() {
        let vm = makePhaseTaggedFixtureViewModel()
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "phase_test")

        // No telemetry received yet -- FlightAnalysisEngine's default
        // phase is `.unknown`, which only the "ground" section is tagged for.
        #expect(vm.currentFlightPhase == .unknown)
        #expect(vm.suggestedSection?.id == "ground")
    }

    @Test func suggestionDisappearsOnceTheMatchingSectionIsFullyDone() {
        let vm = makePhaseTaggedFixtureViewModel()
        vm.selectProcedure(aircraftId: "a320_neo", procedureId: "phase_test")
        vm.toggleStepCompleted("ground_step")
        #expect(vm.suggestedSection == nil)
    }

    // MARK: - Fixture builders

    private func makeAutomaticFixtureViewModel(
        condition: ProcedureAutomaticCondition,
        progressStore: ProcedureProgressStoring = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())
    ) -> ProceduresViewModel {
        let step = ProcedureStep(
            id: "auto_step",
            order: 1,
            title: "Auto Step",
            instruction: "Auto-verified step.",
            purpose: "Testing automatic verification.",
            location: ProcedureFixtures.location,
            expectedResult: ["Condition satisfied"],
            verification: ProcedureVerification(mode: .automatic, condition: condition),
            condition: nil,
            caution: nil,
            notes: nil,
            estimatedSeconds: 5,
            difficulty: .beginner,
            highlight: nil,
            references: nil
        )
        let procedure = AircraftProcedure(
            id: "auto_test",
            title: "Auto Test",
            aircraft: "a320_neo",
            version: 1,
            estimatedMinutes: 1,
            difficulty: .beginner,
            fidelity: .aeroflyVerified,
            disclaimer: "Test only.",
            sources: [],
            sections: [
                ProcedureSection(id: "sec", title: "Section", order: 1, optional: false, steps: [step])
            ]
        )
        let loader = FakeKnowledgeDataLoader(
            aircraftIndex: ["a320_neo"],
            aircraftByID: ["a320_neo": Self.aircraft(supporting: "auto_test")],
            proceduresByKey: ["a320_neo.auto_test": procedure]
        )
        return makeViewModel(loader: loader, progressStore: progressStore)
    }

    private func makePhaseTaggedFixtureViewModel(
        progressStore: ProcedureProgressStoring = ProcedureProgressStore(userDefaults: Self.makeIsolatedDefaults())
    ) -> ProceduresViewModel {
        let procedure = AircraftProcedure(
            id: "phase_test",
            title: "Phase Test",
            aircraft: "a320_neo",
            version: 1,
            estimatedMinutes: 1,
            difficulty: .beginner,
            fidelity: .aeroflyVerified,
            disclaimer: "Test only.",
            sources: [],
            sections: [
                ProcedureSection(
                    id: "ground",
                    title: "Ground",
                    order: 1,
                    optional: false,
                    applicablePhases: ["unknown", "parked"],
                    steps: [ProcedureFixtures.step(id: "ground_step", order: 1, title: "Ground Step")]
                ),
                ProcedureSection(
                    id: "cruise",
                    title: "Cruise",
                    order: 2,
                    optional: false,
                    applicablePhases: ["cruise"],
                    steps: [ProcedureFixtures.step(id: "cruise_step", order: 1, title: "Cruise Step")]
                )
            ]
        )
        let loader = FakeKnowledgeDataLoader(
            aircraftIndex: ["a320_neo"],
            aircraftByID: ["a320_neo": Self.aircraft(supporting: "phase_test")],
            proceduresByKey: ["a320_neo.phase_test": procedure]
        )
        return makeViewModel(loader: loader, progressStore: progressStore)
    }

    /// `ProcedureService` only loads procedures listed in the aircraft's
    /// own `supportedProcedures` (see `ProcedureService.init`), so each
    /// bespoke fixture procedure needs a matching aircraft record rather
    /// than reusing `ProcedureFixtures.a320Aircraft` (which only lists
    /// `cold_and_dark`).
    private static func aircraft(supporting procedureId: String) -> ProcedureAircraft {
        ProcedureAircraft(
            id: "a320_neo",
            name: "Airbus A320neo",
            manufacturer: "Airbus",
            family: "airbus_fb",
            category: "airliner",
            fidelity: .aeroflyVerified,
            supportedProcedures: [procedureId],
            inheritsProceduresFrom: nil
        )
    }
}
