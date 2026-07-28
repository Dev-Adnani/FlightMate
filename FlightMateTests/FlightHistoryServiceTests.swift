//
//  FlightHistoryServiceTests.swift
//  FlightMateTests
//
//  Pure-function tests for FlightHistoryService (and the FlightHistory
//  model's own value-semantics) -- no networking, no timers, no Combine.
//  Every FlightEvent is constructed directly, so these run instantly and
//  deterministically.
//

import Foundation
import Testing
@testable import FlightMate

struct FlightHistoryServiceTests {

    // MARK: - Starting a history

    @Test func aircraftLoadedStartsANewActiveHistorySeededWithThatEvent() {
        let event = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo")

        let result = FlightHistoryService.apply(event: event, to: .init(), maxCompletedHistories: 25)

        #expect(result.currentHistory?.status == .active)
        #expect(result.currentHistory?.events == [event])
        #expect(result.currentHistory?.startTime == event.timestamp)
        #expect(result.currentHistory?.currentAircraft?.aircraftCode == "a320_neo")
        #expect(result.completedHistories.isEmpty)
    }

    @Test func nonAircraftEventIsDroppedWhenNoHistoryIsActive() {
        let event = makeEvent(type: .telemetryLost)

        let result = FlightHistoryService.apply(event: event, to: .init(), maxCompletedHistories: 25)

        #expect(result.currentHistory == nil)
        #expect(result.completedHistories.isEmpty)
    }

    @Test func flightCompletedWithNoActiveHistoryIsDropped() {
        let event = makeEvent(type: .flightCompleted)

        let result = FlightHistoryService.apply(event: event, to: .init(), maxCompletedHistories: 25)

        #expect(result.currentHistory == nil)
        #expect(result.completedHistories.isEmpty)
    }

    // MARK: - Extending a history

    @Test func phaseEventsAppendToTheActiveHistoryInOrder() {
        let loaded = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo")
        var state = FlightHistoryService.apply(event: loaded, to: .init(), maxCompletedHistories: 25)

        let taxi = makeEvent(type: .enteredTaxi)
        state = FlightHistoryService.apply(event: taxi, to: state, maxCompletedHistories: 25)
        let takeoff = makeEvent(type: .takeoffDetected)
        state = FlightHistoryService.apply(event: takeoff, to: state, maxCompletedHistories: 25)

        #expect(state.currentHistory?.events == [loaded, taxi, takeoff])
    }

    // MARK: - Completing a history

    @Test func flightCompletedAppendsThenFinalizesAsCompletedAndMovesToCompletedList() {
        let loaded = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo", timestamp: t(0))
        var state = FlightHistoryService.apply(event: loaded, to: .init(), maxCompletedHistories: 25)
        let cruise = makeEvent(type: .enteredCruise, timestamp: t(60))
        state = FlightHistoryService.apply(event: cruise, to: state, maxCompletedHistories: 25)
        let completed = makeEvent(type: .flightCompleted, timestamp: t(120))

        state = FlightHistoryService.apply(event: completed, to: state, maxCompletedHistories: 25)

        #expect(state.currentHistory == nil)
        #expect(state.completedHistories.count == 1)
        let finished = state.completedHistories[0]
        #expect(finished.status == .completed)
        #expect(finished.endTime == t(120))
        #expect(finished.events == [loaded, cruise, completed])
    }

    // MARK: - Aborting a history (Q4)

    @Test func aircraftChangedWhileActiveAbortsOldHistoryAndImmediatelyStartsANewOneSeededWithTheSameEvent() {
        let loaded = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo", timestamp: t(0))
        var state = FlightHistoryService.apply(event: loaded, to: .init(), maxCompletedHistories: 25)
        let cruise = makeEvent(type: .enteredCruise, aircraftCode: "a320_neo", timestamp: t(60))
        state = FlightHistoryService.apply(event: cruise, to: state, maxCompletedHistories: 25)

        let changed = makeEvent(type: .aircraftChanged, aircraftCode: "c172", timestamp: t(90))
        state = FlightHistoryService.apply(event: changed, to: state, maxCompletedHistories: 25)

        // Old history: aborted, ends exactly at the moment the swap was
        // detected, and is never polluted with the event that ended it.
        #expect(state.completedHistories.count == 1)
        let aborted = state.completedHistories[0]
        #expect(aborted.status == .aborted)
        #expect(aborted.endTime == t(90))
        #expect(aborted.events == [loaded, cruise])
        #expect(aborted.currentAircraft?.aircraftCode == "a320_neo")

        // New history: starts fresh, seeded with the very event that ended
        // the old one -- no idle gap in between.
        #expect(state.currentHistory?.status == .active)
        #expect(state.currentHistory?.events == [changed])
        #expect(state.currentHistory?.startTime == t(90))
        #expect(state.currentHistory?.currentAircraft?.aircraftCode == "c172")
    }

    @Test func aircraftLoadedWhileActiveAlsoAbortsAndRestartsSymmetricallyWithAircraftChanged() {
        // Defensive symmetry case: in practice `aircraftLoaded` only ever
        // fires once per app session (see FlightEventDetectionService), so
        // this path shouldn't normally be reachable with a history already
        // active -- but the service handles it identically to
        // `aircraftChanged` rather than assuming it can't happen.
        let loaded = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo", timestamp: t(0))
        var state = FlightHistoryService.apply(event: loaded, to: .init(), maxCompletedHistories: 25)

        let secondLoaded = makeEvent(type: .aircraftLoaded, aircraftCode: "c172", timestamp: t(5))
        state = FlightHistoryService.apply(event: secondLoaded, to: state, maxCompletedHistories: 25)

        #expect(state.completedHistories.count == 1)
        #expect(state.completedHistories[0].status == .aborted)
        #expect(state.currentHistory?.events == [secondLoaded])
    }

    @Test func aFullFlightThenAnAbortedOneAreBothIndependentlyTracked() {
        var state = FlightHistoryService.State()

        // First flight: completes normally.
        state = FlightHistoryService.apply(event: makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo", timestamp: t(0)), to: state, maxCompletedHistories: 25)
        state = FlightHistoryService.apply(event: makeEvent(type: .enteredTaxi, timestamp: t(10)), to: state, maxCompletedHistories: 25)
        state = FlightHistoryService.apply(event: makeEvent(type: .flightCompleted, timestamp: t(100)), to: state, maxCompletedHistories: 25)
        #expect(state.completedHistories.map { $0.status } == [.completed])

        // Second flight: aborted mid-flight by a new aircraft.
        state = FlightHistoryService.apply(event: makeEvent(type: .aircraftLoaded, aircraftCode: "c172", timestamp: t(200)), to: state, maxCompletedHistories: 25)
        state = FlightHistoryService.apply(event: makeEvent(type: .aircraftChanged, aircraftCode: "cessna_caravan", timestamp: t(210)), to: state, maxCompletedHistories: 25)

        #expect(state.completedHistories.map { $0.status } == [.completed, .aborted])
        #expect(state.currentHistory?.currentAircraft?.aircraftCode == "cessna_caravan")
    }

    // MARK: - Bounded completed-history list

    @Test func completedHistoriesListIsBoundedDroppingOldestFirst() {
        var state = FlightHistoryService.State()
        for index in 0..<5 {
            state = FlightHistoryService.apply(
                event: makeEvent(type: .aircraftLoaded, aircraftCode: "aircraft-\(index)", timestamp: t(Double(index) * 100)),
                to: state, maxCompletedHistories: 3
            )
            state = FlightHistoryService.apply(
                event: makeEvent(type: .flightCompleted, aircraftCode: "aircraft-\(index)", timestamp: t(Double(index) * 100 + 50)),
                to: state, maxCompletedHistories: 3
            )
        }

        #expect(state.completedHistories.count == 3)
        // Oldest (aircraft-0, aircraft-1) dropped; newest 3 retained, in order.
        #expect(state.completedHistories.map { $0.currentAircraft?.aircraftCode } == ["aircraft-2", "aircraft-3", "aircraft-4"])
    }

    // MARK: - FlightHistory model value semantics

    @Test func appendingReturnsANewValueWithoutMutatingTheOriginal() {
        let first = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo")
        let original = FlightHistory(id: UUID(), firstEvent: first)

        let second = makeEvent(type: .enteredTaxi)
        let extended = original.appending(second)

        #expect(original.events == [first])
        #expect(extended.events == [first, second])
    }

    @Test func finalizedReturnsANewValueWithoutMutatingTheOriginal() {
        let first = makeEvent(type: .aircraftLoaded, aircraftCode: "a320_neo")
        let original = FlightHistory(id: UUID(), firstEvent: first)

        let finished = original.finalized(as: .completed, at: t(500))

        #expect(original.status == .active)
        #expect(original.endTime == nil)
        #expect(finished.status == .completed)
        #expect(finished.endTime == t(500))
    }

    @Test func derivedFieldsReadFromTheMostRecentEventsAnalysis() {
        let loaded = makeEvent(
            type: .aircraftLoaded, aircraftCode: "a320_neo",
            departureICAO: "EDDF", destinationICAO: "EGLL", durationSeconds: 10
        )
        var history = FlightHistory(id: UUID(), firstEvent: loaded)
        #expect(history.currentAircraft?.aircraftCode == "a320_neo")
        #expect(history.departureAirport?.icaoCode == "EDDF")
        #expect(history.destinationAirport?.icaoCode == "EGLL")
        #expect(history.durationSeconds == 10)

        // A later event's analysis snapshot supersedes the earlier one.
        let cruise = makeEvent(
            type: .enteredCruise, aircraftCode: "a320_neo",
            departureICAO: "EDDF", destinationICAO: "EGLL", durationSeconds: 600
        )
        history = history.appending(cruise)
        #expect(history.durationSeconds == 600)
    }
}

// MARK: - Test helpers

private func t(_ secondsSinceReferenceDate: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: secondsSinceReferenceDate)
}

private func makeEvent(
    type: FlightEventType,
    aircraftCode: String? = nil,
    timestamp: Date = Date(timeIntervalSinceReferenceDate: 0),
    departureICAO: String? = nil,
    destinationICAO: String? = nil,
    durationSeconds: TimeInterval? = nil,
    metadata: FlightEventMetadata? = nil
) -> FlightEvent {
    var analysis = FlightAnalysis.idle
    analysis.resolvedAircraft = aircraftCode.map { ResolvedAircraft(aircraftCode: $0, liveryCode: "", aircraft: nil, livery: nil) }
    analysis.resolvedDeparture = departureICAO.map { ResolvedAirport(icaoCode: $0, runwayIdentifier: nil, airport: nil, runway: nil, country: nil) }
    analysis.resolvedDestination = destinationICAO.map { ResolvedAirport(icaoCode: $0, runwayIdentifier: nil, airport: nil, runway: nil, country: nil) }
    analysis.estimatedSessionDurationSeconds = durationSeconds
    analysis.analysisTimestamp = timestamp
    return FlightEvent(
        eventId: UUID(), type: type, timestamp: timestamp, analysis: analysis,
        severity: type.defaultSeverity, metadata: metadata
    )
}
