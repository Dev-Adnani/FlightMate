//
//  AeroflyLoadedAircraftReaderTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct AeroflyLoadedAircraftReaderTests {
    @Test func extractsLastDoneLoadingModelCode() {
        let log = """
        2.93-tmmodelmanager:              model: (name='c172') (directory='aircraft/c172/')
        5.13-tmsimulator:             done loading model c172
        12.01-tmsimulator:             done loading model a320_neo
        """
        #expect(TmLogAeroflyLoadedAircraftReader.extractLoadedAircraft(from: log) == "a320_neo")
    }

    @Test func fallsBackToDynamicsBeginMarker() {
        let log = """
        4.27-tmmodelmanager:              loading dynamics begin 'b787_9'...
        4.83-tmmodelmanager:              loading dynamics end: (id=1)
        """
        #expect(TmLogAeroflyLoadedAircraftReader.extractLoadedAircraft(from: log) == "b787_9")
    }

    @Test func returnsNilWhenNoLoadLineExists() {
        #expect(TmLogAeroflyLoadedAircraftReader.extractLoadedAircraft(from: "hello") == nil)
    }
}

struct AeroflySessionAircraftReconcilerTests {
    @Test func overridesStaleCessnaWithLiveA320() {
        var session = AeroflySession()
        session.aircraft = .init(aeroflyCode: "c172", liveryCode: "classic")
        var entries: [AeroflySessionValidationEntry] = []

        AeroflySessionAircraftReconciler.applyLiveAircraft("a320_neo", to: &session, entries: &entries)

        #expect(session.aircraft?.aeroflyCode == "a320_neo")
        #expect(session.aircraft?.liveryCode == "")
        #expect(entries.contains { $0.field == "aircraft.live" && $0.detail == "overrode main.mcf" })
    }

    @Test func leavesSessionAloneWhenLiveCodeMissing() {
        var session = AeroflySession()
        session.aircraft = .init(aeroflyCode: "c172", liveryCode: "classic")
        var entries: [AeroflySessionValidationEntry] = []

        AeroflySessionAircraftReconciler.applyLiveAircraft(nil, to: &session, entries: &entries)

        #expect(session.aircraft?.aeroflyCode == "c172")
        #expect(entries.isEmpty)
    }
}
