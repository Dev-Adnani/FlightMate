//
//  AeroflyWeatherMappingTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct AeroflyWeatherMappingTests {
    @Test func windSpeedPercentMatchesMissionsgeraetFormula() {
        // knots = 8*(p+p²); for p=0.5 → 8*(0.5+0.25)=6
        let percent = AeroflyEditableWeather.windSpeedPercent(fromKnots: 6)
        #expect(abs(percent - 0.5) < 0.001)
    }

    @Test func coverCodesMapToFractions() {
        #expect(AeroflyEditableWeather.coverFraction(forCode: "FEW") == 1.0 / 8.0)
        #expect(AeroflyEditableWeather.coverFraction(forCode: "OVC") == 1)
        #expect(AeroflyEditableWeather.coverFraction(forCode: "CLR") == 0)
    }

    @Test func mcfFractionsProduceVisibilityAndClouds() {
        let weather = AeroflyEditableWeather(
            windDirectionDegrees: 270,
            windSpeedKnots: 10,
            windGustKnots: 15,
            temperatureCelsius: 12,
            visibilityStatuteMiles: 10,
            clouds: [
                .init(coverFraction: 0.5, heightFeetAGL: 2000),
                .init(coverFraction: 0, heightFeetAGL: 0),
                .init(coverFraction: 0, heightFeetAGL: 0),
            ]
        )
        let fractions = weather.mcfFractions()
        #expect(fractions.visibility == 1 || abs(fractions.visibility - 1) < 0.05)
        #expect(abs(fractions.cumulusHeight - 0.2) < 0.001)
        #expect(fractions.cumulusDensity == 0.5)
        #expect(weather.flightCategory == .vfr || weather.flightCategory == .mvfr)
    }
}
