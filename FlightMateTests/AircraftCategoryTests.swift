//
//  AircraftCategoryTests.swift
//  FlightMateTests
//
//  Verifies AircraftCategory's tag-priority order matches the source data's
//  own aircraft picker grouping logic (src/aircraft-functions.js).
//

import Testing
@testable import FlightMate

struct AircraftCategoryTests {

    @Test func historicalTakesPriorityOverAirliner() {
        let category = AircraftCategory(tags: ["historical", "airliner"])

        #expect(category == .historical)
    }

    @Test func airlinerTakesPriorityOverHelicopterAndMilitary() {
        let category = AircraftCategory(tags: ["airliner", "helicopter", "military"])

        #expect(category == .airliner)
    }

    @Test func helicopterTakesPriorityOverMilitary() {
        let category = AircraftCategory(tags: ["helicopter", "military"])

        #expect(category == .helicopter)
    }

    @Test func militaryTakesPriorityOverGliderAndAerobatic() {
        let category = AircraftCategory(tags: ["military", "glider", "aerobatic"])

        #expect(category == .military)
    }

    @Test func gliderTakesPriorityOverAerobatic() {
        let category = AircraftCategory(tags: ["glider", "aerobatic"])

        #expect(category == .glider)
    }

    @Test func aerobaticIsUsedWhenNoHigherPriorityTagPresent() {
        let category = AircraftCategory(tags: ["airplane", "aerobatic"])

        #expect(category == .aerobatic)
    }

    @Test func generalAviationIsTheFallback() {
        let category = AircraftCategory(tags: ["airplane", "ga"])

        #expect(category == .generalAviation)
    }

    @Test func emptyTagsFallBackToGeneralAviation() {
        #expect(AircraftCategory(tags: []) == .generalAviation)
    }
}
