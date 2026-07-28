//
//  FlightAnalysisServicePhaseTests.swift
//  FlightMateTests
//
//  Pure-function tests for FlightAnalysisService.determinePhase(_:) --
//  split from FlightAnalysisServiceTests.swift to respect the
//  300-line-per-file rule, mirroring the FlightAnalysisService/
//  FlightAnalysisService+Phase.swift split on the source side.
//

import Foundation
import Testing
@testable import FlightMate

struct FlightAnalysisServicePhaseTests {

    @Test func unknownWhenNoTelemetryYet() {
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(groundSpeedKts: nil, altitudeFeet: nil))
        #expect(phase == .unknown)
        #expect(!reasons.isEmpty)
    }

    @Test func parkedWhenSpeedNearZeroAndLevel() {
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(groundSpeedKts: 0, altitudeFeet: 0, previousPhase: .unknown))
        #expect(phase == .parked)
    }

    @Test func taxiWhenSpeedInTaxiRangeAndLevel() {
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(groundSpeedKts: 15, altitudeFeet: 0, previousPhase: .parked))
        #expect(phase == .taxi)
    }

    @Test func takeoffWhenAboveTaxiSpeedNotYetClimbingAndNotAlreadyAirborne() {
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(groundSpeedKts: 60, altitudeFeet: 0, previousPhase: .taxi))
        #expect(phase == .takeoff)
    }

    @Test func takeoffNeverRefiresDuringAnEstablishedCruise() {
        // Regression test: cruise is also level and fast, so ".takeoff"
        // must never re-fire once the previous phase is already airborne.
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 450, altitudeFeet: 30_000, previousPhase: .cruise, profile: a320Profile
        ))
        #expect(phase == .cruise)
    }

    @Test func climbWhenClimbingBelowCruiseAltitudeThreshold() {
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 300, altitudeFeet: 10_000, isClimbing: true, previousPhase: .takeoff, profile: a320Profile
        ))
        #expect(phase == .climb)
        #expect(reasons.contains("Below cruise altitude threshold"))
    }

    @Test func climbFallsBackGracefullyWhenAircraftUnresolved() {
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 300, altitudeFeet: 10_000, isClimbing: true, previousPhase: .takeoff, profile: .genericFallback
        ))
        #expect(phase == .climb)
        #expect(reasons.contains("Aircraft cruise altitude unknown"))
    }

    @Test func cruiseWhenLevelFastAndAtOrAboveCruiseAltitude() {
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 450, altitudeFeet: 30_000, previousPhase: .climb, profile: a320Profile
        ))
        #expect(phase == .cruise)
    }

    @Test func descentWhenDescendingBeyondApproachProximity() {
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 300, altitudeFeet: 15_000, isDescending: true,
            distanceToNearestAirportNauticalMiles: 50, previousPhase: .cruise, profile: a320Profile
        ))
        #expect(phase == .descent)
        #expect(reasons.contains("Beyond approach proximity of nearest airport"))
    }

    @Test func descentWhenNearestAirportUnknown() {
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 300, altitudeFeet: 15_000, isDescending: true,
            distanceToNearestAirportNauticalMiles: nil, previousPhase: .cruise, profile: a320Profile
        ))
        #expect(phase == .descent)
        #expect(reasons.contains("Nearest airport unknown"))
    }

    @Test func approachWhenDescendingWithinProximityAndDecelerating() {
        let (phase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 150, altitudeFeet: 3_000, isDescending: true,
            distanceToNearestAirportNauticalMiles: 10, previousPhase: .descent, profile: a320Profile
        ))
        #expect(phase == .approach)
    }

    @Test func landingContinuesAcrossMultipleTicksThenDecaysToTaxi() {
        // Tick 1: previous phase was ".approach", speed has dropped below
        // approach speed but still above taxi range -> landing.
        let (firstPhase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 110, altitudeFeet: 0, previousPhase: .approach, profile: a320Profile
        ))
        #expect(firstPhase == .landing)

        // Tick 2: previous phase is now ".landing" itself -- the rule must
        // keep re-firing (hysteresis) as long as speed stays above taxi range.
        let (secondPhase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 60, altitudeFeet: 0, previousPhase: .landing, profile: a320Profile
        ))
        #expect(secondPhase == .landing)

        // Tick 3: speed has finally decayed into the taxi range -- landing
        // naturally falls through to taxi, no explicit timer involved.
        let (thirdPhase, _) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 30, altitudeFeet: 0, previousPhase: .landing, profile: a320Profile
        ))
        #expect(thirdPhase == .taxi)
    }

    @Test func retainsPreviousPhaseWhenNoRuleMatchesCleanly() {
        // Level, faster than taxi, but altitude below cruise threshold
        // with a previous phase that isn't airborne-eligible for takeoff
        // (already ".cruise") and isn't climbing/descending either.
        let (phase, reasons) = FlightAnalysisService.determinePhase(makeInputs(
            groundSpeedKts: 300, altitudeFeet: 10_000, previousPhase: .cruise, profile: a320Profile
        ))
        #expect(phase == .cruise)
        #expect(reasons.contains("No clear phase transition detected; retaining previous phase"))
    }
}

// MARK: - Test helpers

private let a320Profile = FlightPerformanceProfile.make(from: ResolvedAircraft(
    aircraftCode: "a320_neo", liveryCode: "", aircraft: ReferenceDataFixtures.a320, livery: nil
))

private func makeInputs(
    groundSpeedKts: Double?,
    altitudeFeet: Double?,
    isClimbing: Bool = false,
    isDescending: Bool = false,
    distanceToNearestAirportNauticalMiles: Double? = nil,
    previousPhase: FlightPhase = .unknown,
    profile: FlightPerformanceProfile = .genericFallback
) -> FlightAnalysisService.PhaseInputs {
    FlightAnalysisService.PhaseInputs(
        groundSpeedKts: groundSpeedKts,
        altitudeFeet: altitudeFeet,
        isClimbing: isClimbing,
        isDescending: isDescending,
        distanceToNearestAirportNauticalMiles: distanceToNearestAirportNauticalMiles,
        performanceProfile: profile,
        previousPhase: previousPhase
    )
}
