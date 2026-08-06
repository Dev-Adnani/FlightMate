//
//  AeroflyWeatherMapping.swift
//  FlightMate
//
//  Converts METAR / editor units into Aerofly main.mcf weather fractions.
//  Formulas ported from fboes/aerofly-missions MissionConditions.
//

import Foundation

/// Editable weather in aviation units (Startgerät-style), ready for MCF apply.
struct AeroflyEditableWeather: Equatable, Sendable {
    var windDirectionDegrees: Double
    /// Knots
    var windSpeedKnots: Double
    var windGustKnots: Double
    /// °C
    var temperatureCelsius: Double
    /// Statute miles (0…10)
    var visibilityStatuteMiles: Double
    /// Up to three layers: cover fraction 0…1, height feet AGL
    var clouds: [CloudLayer]

    struct CloudLayer: Equatable, Sendable {
        var coverFraction: Double
        var heightFeetAGL: Double
    }

    /// MCF-ready fractions (0…1) plus visibility fraction.
    struct MCFFractions: Equatable, Sendable {
        var windStrength: Double
        var windDirectionDegrees: Double
        var turbulence: Double
        var thermalActivity: Double
        var visibility: Double
        var cumulusDensity: Double
        var cumulusHeight: Double
        var mediocrisDensity: Double
        var mediocrisHeight: Double
        var cirrusDensity: Double
        var cirrusHeight: Double
    }

    static func from(metar: METARObservation) -> AeroflyEditableWeather {
        let layers = metar.clouds.prefix(3).map { layer in
            CloudLayer(
                coverFraction: coverFraction(forCode: layer.coverCode),
                heightFeetAGL: layer.baseFeetAGL ?? 0
            )
        }
        return AeroflyEditableWeather(
            windDirectionDegrees: metar.windDirectionDegrees ?? 0,
            windSpeedKnots: metar.windSpeedKnots,
            windGustKnots: metar.windGustKnots ?? metar.windSpeedKnots,
            temperatureCelsius: metar.temperatureCelsius ?? 14,
            visibilityStatuteMiles: min(10, metar.visibilityStatuteMiles),
            clouds: Array(layers)
        )
    }

    func mcfFractions() -> MCFFractions {
        let windPercent = Self.windSpeedPercent(fromKnots: windSpeedKnots)
        let gustDelta = max(0, windGustKnots - windSpeedKnots)
        let turbulence = min(1, windSpeedKnots / 80 + gustDelta / 20)
        // Visibility: Missionsgerät uses meters / 15000; 1 SM ≈ 1609 m.
        let visibilityMeters = min(15000, visibilityStatuteMiles * 1609.344)
        let visibility = min(1, visibilityMeters / 15000)

        func heightPercent(_ feet: Double) -> Double {
            min(1, max(0, feet / 10_000))
        }

        let c0 = clouds.indices.contains(0) ? clouds[0] : CloudLayer(coverFraction: 0, heightFeetAGL: 0)
        let c1 = clouds.indices.contains(1) ? clouds[1] : CloudLayer(coverFraction: 0, heightFeetAGL: 0)
        let c2 = clouds.indices.contains(2) ? clouds[2] : CloudLayer(coverFraction: 0, heightFeetAGL: 0)

        return MCFFractions(
            windStrength: windPercent,
            windDirectionDegrees: windDirectionDegrees.truncatingRemainder(dividingBy: 360),
            turbulence: turbulence,
            thermalActivity: 0,
            visibility: visibility,
            cumulusDensity: c0.coverFraction,
            cumulusHeight: heightPercent(c0.heightFeetAGL),
            mediocrisDensity: c1.coverFraction,
            mediocrisHeight: heightPercent(c1.heightFeetAGL),
            cirrusDensity: c2.coverFraction,
            cirrusHeight: heightPercent(c2.heightFeetAGL)
        )
    }

    var flightCategory: FlightCategory {
        let ceiling = clouds.first(where: { $0.coverFraction > 0.5 })?.heightFeetAGL
        return .us(visibilitySM: visibilityStatuteMiles, ceilingFeet: ceiling)
    }

    /// Inverse of Missionsgerät: knots = 8 * (p + p²) → p = √(k/8 + 0.25) − 0.5
    static func windSpeedPercent(fromKnots knots: Double) -> Double {
        let p = (knots / 8 + 0.25).squareRoot() - 0.5
        return min(1, max(0, p))
    }

    static func coverFraction(forCode code: String) -> Double {
        switch code.uppercased() {
        case "CLR", "SKC", "CAVOK": return 0
        case "FEW": return 1.0 / 8.0
        case "SCT": return 2.0 / 8.0
        case "BKN": return 4.0 / 8.0
        case "OVC": return 1
        default: return 0
        }
    }
}
