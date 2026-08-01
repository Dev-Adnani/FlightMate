//
//  FlightEventDetectionServiceTests.swift
//  FlightMateTests
//
//  Pure-function tests for FlightEventDetectionService -- no networking, no
//  timers, no Combine. Every FlightAnalysis pair is constructed directly,
//  so these run instantly and deterministically.
//

import Foundation
import Testing
@testable import FlightMate

struct FlightEventDetectionServiceTests {

    // MARK: - Phase-entry events

    @Test func enteredTaxiFiresOnceOnTransitionIntoTaxi() {
        let previous = makeAnalysis(flightPhase: .parked)
        let current = makeAnalysis(flightPhase: .taxi)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.enteredTaxi])
    }

    @Test func takeoffDetectedFiresOnceOnTransitionIntoTakeoff() {
        let previous = makeAnalysis(flightPhase: .taxi)
        let current = makeAnalysis(flightPhase: .takeoff)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.takeoffDetected])
    }

    @Test func enteredClimbFiresOnceOnTransitionIntoClimb() {
        // Regression test (bugfix-climb-event): without this mapping, a
        // flight that goes taxi -> climb directly (skipping the momentary
        // .takeoff phase) never latches a flight-clock start.
        let previous = makeAnalysis(flightPhase: .takeoff)
        let current = makeAnalysis(flightPhase: .climb)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.enteredClimb])
    }

    @Test func enteredCruiseFiresOnceOnTransitionIntoCruise() {
        let previous = makeAnalysis(flightPhase: .climb)
        let current = makeAnalysis(flightPhase: .cruise)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.enteredCruise])
    }

    @Test func enteredDescentFiresOnceOnTransitionIntoDescent() {
        let previous = makeAnalysis(flightPhase: .cruise)
        let current = makeAnalysis(flightPhase: .descent)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.enteredDescent])
    }

    @Test func enteredApproachFiresOnceOnTransitionIntoApproach() {
        let previous = makeAnalysis(flightPhase: .descent)
        let current = makeAnalysis(flightPhase: .approach)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.enteredApproach])
    }

    @Test func landingDetectedFiresOnceOnTransitionIntoLanding() {
        let previous = makeAnalysis(flightPhase: .approach)
        let current = makeAnalysis(flightPhase: .landing)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.landingDetected])
    }

    @Test func noPhaseEventWhenRemainingInTheSamePhase() {
        let analysis = makeAnalysis(flightPhase: .cruise)

        let result = FlightEventDetectionService.detectEvents(previous: analysis, current: analysis, state: .init())
        #expect(result.events.isEmpty)
    }

    @Test func noPhaseEventWhenEnteringParkedOrUnknown() {
        // .parked has its own dedicated (gated) FlightCompleted rule --
        // it must never also fire a generic phase-entry event.
        let toParked = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .taxi), current: makeAnalysis(flightPhase: .parked), state: .init()
        )
        #expect(toParked.events.isEmpty)

        let toUnknown = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .parked), current: makeAnalysis(flightPhase: .unknown), state: .init()
        )
        #expect(toUnknown.events.isEmpty)
    }

    // MARK: - Flight completed

    @Test func flightCompletedDoesNotFireWhenReachingParkedWithoutHavingBeenAirborne() {
        let previous = makeAnalysis(flightPhase: .taxi)
        let current = makeAnalysis(flightPhase: .parked)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(!result.events.map { $0.type }.contains(.flightCompleted))
        #expect(result.updatedState.hasBeenAirborneThisSession == false)
    }

    @Test func flightCompletedFiresOnceAfterBeingAirborneAndReachingParked() {
        var state = FlightEventDetectionService.DetectionState()

        let liftoff = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .takeoff), current: makeAnalysis(flightPhase: .climb), state: state
        )
        state = liftoff.updatedState
        #expect(state.hasBeenAirborneThisSession)

        let landed = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .landing), current: makeAnalysis(flightPhase: .taxi), state: state
        )
        state = landed.updatedState

        let parked = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .taxi), current: makeAnalysis(flightPhase: .parked), state: state
        )
        #expect(parked.events.map { $0.type } == [.flightCompleted])
        #expect(parked.updatedState.hasBeenAirborneThisSession == false)
    }

    @Test func flightCompletedLatchResetsSoASecondFlightRequiresBecomingAirborneAgain() {
        var state = FlightEventDetectionService.DetectionState(hasBeenAirborneThisSession: false)

        // First completed flight.
        state.hasBeenAirborneThisSession = true
        let firstParked = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .taxi), current: makeAnalysis(flightPhase: .parked), state: state
        )
        state = firstParked.updatedState
        #expect(firstParked.events.map { $0.type } == [.flightCompleted])

        // A later taxi-and-park without ever having left the ground again
        // must not refire FlightCompleted.
        let taxiAgain = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .parked), current: makeAnalysis(flightPhase: .taxi), state: state
        )
        state = taxiAgain.updatedState
        let parkedAgain = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(flightPhase: .taxi), current: makeAnalysis(flightPhase: .parked), state: state
        )
        #expect(!parkedAgain.events.map { $0.type }.contains(.flightCompleted))
    }

    @Test func flightCompletedDoesNotFireWhenAlreadyParked() {
        let analysis = makeAnalysis(flightPhase: .parked)
        let state = FlightEventDetectionService.DetectionState(hasBeenAirborneThisSession: true)

        let result = FlightEventDetectionService.detectEvents(previous: analysis, current: analysis, state: state)
        #expect(result.events.isEmpty)
    }

    // MARK: - Aircraft identity

    @Test func aircraftLoadedFiresWhenAircraftFirstBecomesKnown() {
        let previous = makeAnalysis(resolvedAircraft: nil)
        let current = makeAnalysis(resolvedAircraft: makeAircraft(code: "a320_neo"))

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.aircraftLoaded])
        #expect(result.updatedState.lastKnownAircraft?.aircraftCode == "a320_neo")
    }

    @Test func aircraftChangedFiresWithBothAircraftAsMetadataOnceConfirmedOverTwoSamples() {
        let a320 = makeAircraft(code: "a320_neo")
        let c172 = makeAircraft(code: "c172")
        var state = FlightEventDetectionService.DetectionState(lastKnownAircraft: a320)

        // First sample of the new code: only becomes a pending candidate,
        // doesn't emit or update lastKnownAircraft yet.
        let firstSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: a320), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = firstSample.updatedState
        #expect(firstSample.events.isEmpty)
        #expect(state.lastKnownAircraft?.aircraftCode == "a320_neo")
        #expect(state.pendingAircraft?.aircraftCode == "c172")

        // Second consecutive sample confirms it -- now it fires.
        let secondSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: c172), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = secondSample.updatedState

        #expect(secondSample.events.map { $0.type } == [.aircraftChanged])
        let metadata = secondSample.events.first(where: { $0.type == .aircraftChanged })?.metadata
        #expect(metadata == .aircraftChange(previous: a320, current: c172))
        #expect(state.lastKnownAircraft?.aircraftCode == "c172")
        #expect(state.pendingAircraft == nil)
    }

    @Test func singleSampleAircraftFlickerNeverEmitsAndRevertsCleanly() {
        // e.g. main.mcf/tm.log briefly disagreeing mid-reparse: the new
        // code appears once, then reverts back to the original on the
        // very next sample -- must never fire aircraftChanged.
        let a320 = makeAircraft(code: "a320_neo")
        let c172 = makeAircraft(code: "c172")
        var state = FlightEventDetectionService.DetectionState(lastKnownAircraft: a320)

        let flicker = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: a320), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = flicker.updatedState
        #expect(state.pendingAircraft?.aircraftCode == "c172")

        let reverted = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: c172), current: makeAnalysis(resolvedAircraft: a320), state: state
        )
        state = reverted.updatedState

        #expect(reverted.events.isEmpty)
        #expect(state.lastKnownAircraft?.aircraftCode == "a320_neo")
        #expect(state.pendingAircraft == nil)
    }

    @Test func confirmedAircraftChangeResetsTheAirborneLatch() {
        // A confirmed in-flight aircraft change must not let the old
        // flight's "has been airborne" latch carry into the new aircraft
        // -- otherwise the new aircraft's first arrival at .parked (even
        // having never flown) would emit a spurious flightCompleted.
        let a320 = makeAircraft(code: "a320_neo")
        let c172 = makeAircraft(code: "c172")
        var state = FlightEventDetectionService.DetectionState(
            hasBeenAirborneThisSession: true, lastKnownAircraft: a320
        )

        let firstSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: a320), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = firstSample.updatedState
        #expect(state.hasBeenAirborneThisSession) // not yet confirmed -- unchanged

        let secondSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: c172), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = secondSample.updatedState
        #expect(!state.hasBeenAirborneThisSession)
    }

    @Test func noAircraftEventWhenAircraftCodeUnchanged() {
        let a320 = makeAircraft(code: "a320_neo")
        let state = FlightEventDetectionService.DetectionState(lastKnownAircraft: a320)

        let result = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: a320), current: makeAnalysis(resolvedAircraft: a320), state: state
        )
        #expect(result.events.isEmpty)
    }

    @Test func transientNilAircraftNeitherEmitsNorClearsLastKnownCode() {
        let a320 = makeAircraft(code: "a320_neo")
        var state = FlightEventDetectionService.DetectionState(lastKnownAircraft: a320)

        // A momentary re-parse with no aircraft selection at all.
        let transientNil = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: a320), current: makeAnalysis(resolvedAircraft: nil), state: state
        )
        state = transientNil.updatedState
        #expect(transientNil.events.isEmpty)
        #expect(state.lastKnownAircraft?.aircraftCode == "a320_neo") // never cleared

        // A genuinely different aircraft afterwards still counts as a
        // change against the *last known* code, not the transient nil --
        // confirmed the same way, over two consecutive samples.
        let c172 = makeAircraft(code: "c172")
        let firstSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: nil), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        state = firstSample.updatedState
        #expect(firstSample.events.isEmpty)

        let secondSample = FlightEventDetectionService.detectEvents(
            previous: makeAnalysis(resolvedAircraft: c172), current: makeAnalysis(resolvedAircraft: c172), state: state
        )
        #expect(secondSample.events.map { $0.type } == [.aircraftChanged])
    }

    // MARK: - Telemetry health

    @Test func telemetryLostFiresOnTransitionFromLiveToStale() {
        let previous = makeAnalysis(telemetryHealth: .live)
        let current = makeAnalysis(telemetryHealth: .stale(secondsSinceLastUpdate: 10))

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.telemetryLost])
        #expect(result.updatedState.isTelemetryCurrentlyLost)
    }

    @Test func telemetryLostFiresOnTransitionFromLiveToNotConnected() {
        let previous = makeAnalysis(telemetryHealth: .live)
        let current = makeAnalysis(telemetryHealth: .notConnected)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.map { $0.type } == [.telemetryLost])
    }

    @Test func telemetryRecoveredFiresOnlyAfterHavingBeenLost() {
        let state = FlightEventDetectionService.DetectionState(isTelemetryCurrentlyLost: true)
        let previous = makeAnalysis(telemetryHealth: .stale(secondsSinceLastUpdate: 10))
        let current = makeAnalysis(telemetryHealth: .live)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: state)
        #expect(result.events.map { $0.type } == [.telemetryRecovered])
        #expect(result.updatedState.isTelemetryCurrentlyLost == false)
    }

    @Test func telemetryRecoveredDoesNotFireOnTheVeryFirstConnection() {
        // .acquiring -> .live at startup is not a "recovery" -- there was
        // nothing to recover from, and isTelemetryCurrentlyLost was never set.
        let previous = makeAnalysis(telemetryHealth: .acquiring)
        let current = makeAnalysis(telemetryHealth: .live)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(result.events.isEmpty)
    }

    @Test func noDuplicateTelemetryLostWhileAlreadyUnhealthy() {
        let state = FlightEventDetectionService.DetectionState(isTelemetryCurrentlyLost: true)
        let previous = makeAnalysis(telemetryHealth: .stale(secondsSinceLastUpdate: 5))
        let current = makeAnalysis(telemetryHealth: .notConnected)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: state)
        #expect(result.events.isEmpty)
    }

    // MARK: - Multiple simultaneous events

    @Test func aSingleTransitionCanProduceMultipleEvents() {
        let a320 = makeAircraft(code: "a320_neo")
        let previous = makeAnalysis(flightPhase: .climb, telemetryHealth: .live, resolvedAircraft: nil)
        let current = makeAnalysis(flightPhase: .cruise, telemetryHealth: .stale(secondsSinceLastUpdate: 5), resolvedAircraft: a320)

        let result = FlightEventDetectionService.detectEvents(previous: previous, current: current, state: .init())
        #expect(Set(result.events.map { $0.type }) == [.aircraftLoaded, .enteredCruise, .telemetryLost])
    }

    // MARK: - Severity

    @Test func everyCurrentEventTypeDefaultsToInfoSeverity() {
        let allTypes: [FlightEventType] = [
            .aircraftLoaded, .aircraftChanged, .enteredTaxi, .takeoffDetected, .enteredClimb, .enteredCruise,
            .enteredDescent, .enteredApproach, .landingDetected, .flightCompleted,
            .telemetryLost, .telemetryRecovered
        ]
        for type in allTypes {
            #expect(type.defaultSeverity == .info)
        }
    }
}

// MARK: - Test helpers

private func makeAnalysis(
    flightPhase: FlightPhase = .unknown,
    telemetryHealth: TelemetryHealth = .notConnected,
    resolvedAircraft: ResolvedAircraft? = nil
) -> FlightAnalysis {
    var analysis = FlightAnalysis.idle
    analysis.flightPhase = flightPhase
    analysis.telemetryHealth = telemetryHealth
    analysis.resolvedAircraft = resolvedAircraft
    return analysis
}

private func makeAircraft(code: String) -> ResolvedAircraft {
    ResolvedAircraft(aircraftCode: code, liveryCode: "", aircraft: nil, livery: nil)
}
