//
//  ProcedurePhaseTaggingTests.swift
//  FlightMateTests
//
//  Covers FlightPhase's procedure-content name parsing and
//  ProcedureSection's phase-applicability rules used by phase-aware
//  checklist navigation.
//

import Testing
@testable import FlightMate

struct ProcedurePhaseTaggingTests {

    // MARK: - FlightPhase(procedureContentName:)

    @Test func parsesEveryValidPhaseName() {
        #expect(FlightPhase(procedureContentName: "unknown") == .unknown)
        #expect(FlightPhase(procedureContentName: "parked") == .parked)
        #expect(FlightPhase(procedureContentName: "taxi") == .taxi)
        #expect(FlightPhase(procedureContentName: "takeoff") == .takeoff)
        #expect(FlightPhase(procedureContentName: "climb") == .climb)
        #expect(FlightPhase(procedureContentName: "cruise") == .cruise)
        #expect(FlightPhase(procedureContentName: "descent") == .descent)
        #expect(FlightPhase(procedureContentName: "approach") == .approach)
        #expect(FlightPhase(procedureContentName: "landing") == .landing)
    }

    @Test func returnsNilForUnrecognizedName() {
        #expect(FlightPhase(procedureContentName: "final_approach") == nil)
        #expect(FlightPhase(procedureContentName: "") == nil)
    }

    // MARK: - ProcedureSection.isApplicable

    @Test func untaggedSectionIsApplicableToEveryPhase() {
        let section = ProcedureFixtures.coldAndDark.sections[0]
        #expect(section.applicablePhases == nil)
        #expect(section.isApplicable(to: .unknown))
        #expect(section.isApplicable(to: .cruise))
        #expect(section.isApplicable(to: .landing))
    }

    @Test func taggedSectionIsOnlyApplicableToListedPhases() {
        let section = ProcedureSection(
            id: "landing_checklist",
            title: "Landing Checklist",
            order: 1,
            optional: false,
            applicablePhases: ["approach", "landing"],
            steps: []
        )
        #expect(section.phases == [.approach, .landing])
        #expect(section.isApplicable(to: .approach))
        #expect(section.isApplicable(to: .landing))
        #expect(!section.isApplicable(to: .cruise))
        #expect(!section.isApplicable(to: .parked))
    }

    @Test func unrecognizedPhaseNamesAreDroppedRatherThanFailingTheSection() {
        let section = ProcedureSection(
            id: "s",
            title: "S",
            order: 1,
            optional: false,
            applicablePhases: ["cruise", "warp_speed"],
            steps: []
        )
        #expect(section.phases == [.cruise])
        #expect(section.isApplicable(to: .cruise))
        #expect(!section.isApplicable(to: .taxi))
    }
}
