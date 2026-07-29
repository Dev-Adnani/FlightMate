//
//  ProcedureFixtures.swift
//  FlightMateTests
//
//  In-memory knowledge fixtures for ProcedureService tests.
//

import Foundation
@testable import FlightMate

struct FakeKnowledgeDataLoader: KnowledgeDataLoading {
    var aircraftIndex: [String] = []
    var aircraftByID: [String: ProcedureAircraft] = [:]
    var proceduresByKey: [String: AircraftProcedure] = [:]
    var indexError: Error?
    var aircraftError: Error?
    var procedureError: Error?

    func loadProcedureAircraftIndex() throws -> [String] {
        if let indexError { throw indexError }
        return aircraftIndex
    }

    func loadProcedureAircraft(id: String) throws -> ProcedureAircraft {
        if let aircraftError { throw aircraftError }
        guard let aircraft = aircraftByID[id] else {
            throw KnowledgeDataError.resourceNotFound("\(id).aircraft.json")
        }
        return aircraft
    }

    func loadProcedure(aircraftId: String, procedureId: String) throws -> AircraftProcedure {
        if let procedureError { throw procedureError }
        let key = "\(aircraftId).\(procedureId)"
        guard let procedure = proceduresByKey[key] else {
            throw KnowledgeDataError.resourceNotFound("\(key).json")
        }
        return procedure
    }
}

enum ProcedureFixtures {
    static let location = ProcedureLocation(
        panel: "Overhead",
        section: "Electrical",
        hint: "Top-left"
    )

    static let verification = ProcedureVerification(mode: .manual)

    static func step(
        id: String,
        order: Int,
        title: String = "Step"
    ) -> ProcedureStep {
        ProcedureStep(
            id: id,
            order: order,
            title: title,
            instruction: "Do \(title).",
            purpose: "Because \(title).",
            location: location,
            expectedResult: ["Done"],
            verification: verification,
            condition: nil,
            caution: nil,
            notes: nil,
            estimatedSeconds: 10,
            difficulty: .beginner,
            highlight: nil,
            references: nil
        )
    }

    static let coldAndDark = AircraftProcedure(
        id: "cold_and_dark",
        title: "Cold & Dark Startup",
        aircraft: "a320_neo",
        version: 1,
        estimatedMinutes: 15,
        difficulty: .beginner,
        fidelity: .aeroflyVerified,
        disclaimer: "For Aerofly FS learning only.",
        sources: [ProcedureSource(title: "Test", url: nil)],
        sections: [
            ProcedureSection(
                id: "power_on",
                title: "Power On",
                order: 1,
                optional: false,
                steps: [
                    step(id: "bat_1", order: 1, title: "BAT 1"),
                    step(id: "bat_2", order: 2, title: "BAT 2")
                ]
            ),
            ProcedureSection(
                id: "apu",
                title: "APU",
                order: 2,
                optional: nil,
                steps: [
                    step(id: "apu_start", order: 1, title: "APU START")
                ]
            )
        ]
    )

    static let a320Aircraft = ProcedureAircraft(
        id: "a320_neo",
        name: "Airbus A320neo",
        manufacturer: "Airbus",
        family: "airbus_fb",
        category: "airliner",
        fidelity: .aeroflyVerified,
        supportedProcedures: ["cold_and_dark"],
        inheritsProceduresFrom: nil
    )

    static func makeLoader() -> FakeKnowledgeDataLoader {
        FakeKnowledgeDataLoader(
            aircraftIndex: ["a320_neo"],
            aircraftByID: ["a320_neo": a320Aircraft],
            proceduresByKey: ["a320_neo.cold_and_dark": coldAndDark]
        )
    }
}
