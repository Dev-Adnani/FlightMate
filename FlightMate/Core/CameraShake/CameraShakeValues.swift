//
//  CameraShakeValues.swift
//  FlightMate
//
//  Pilot camera_head spring/damper (and optional seat) values for .tmd edits.
//  Presets from Mar17 / Aerofly forum (May–July 2026). Prefer Kf/Df;
//  Kt/Dt are retained for completeness but often have little effect.
//

import Foundation

struct CameraShakeValues: Equatable, Sendable {
    var kf: Double
    var df: Double
    var kt: Double
    var dt: Double
    /// Optional eye position override `[x y z]`.
    var r0: [Double]?
    /// Optional look direction `[x y z]`.
    var direction: [Double]?
}

struct CameraShakePreset: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    /// Aerofly aircraft folder code, e.g. `b737_800`.
    let aeroflyCode: String
    let values: CameraShakeValues
    let notes: String?

    static let mar17Forum: [CameraShakePreset] = [
        CameraShakePreset(
            id: "f18",
            displayName: "F/A-18 Hornet",
            aeroflyCode: "f18",
            values: CameraShakeValues(
                kf: 1.45, df: 0.30, kt: 0.0004, dt: 0.0002,
                r0: [5.32, 0.0, 1.30],
                direction: [1.0, 0.0, -0.23]
            ),
            notes: nil
        ),
        CameraShakePreset(
            id: "b737_800",
            displayName: "Boeing 737-800",
            aeroflyCode: "b737_800",
            values: CameraShakeValues(
                kf: 1.25, df: 0.32, kt: 1.000041, dt: 1.000008,
                r0: [16.55, 0.51, 0.81],
                direction: [1.0, 0.0, -0.21]
            ),
            notes: "Mar17 forum values (Kf/Df/Kt/Dt as posted)."
        ),
        CameraShakePreset(
            id: "a321_xlr",
            displayName: "Airbus A321XLR",
            aeroflyCode: "a321_xlr",
            values: CameraShakeValues(
                kf: 0.85, df: 0.23, kt: 2.000022, dt: 2.000015,
                r0: [16.30, 0.5, 0.280],
                direction: [1.0, 0.0, -0.26]
            ),
            notes: "Taller pilot eye point."
        ),
        CameraShakePreset(
            id: "a350_1000",
            displayName: "Airbus A350-1000",
            aeroflyCode: "a350_1000",
            values: CameraShakeValues(
                kf: 0.95, df: 0.34, kt: 1.0022, dt: 1.0002,
                r0: [32.93, 0.53, 0.895],
                direction: [1.0, 0.0, -0.23]
            ),
            notes: nil
        ),
        CameraShakePreset(
            id: "a380",
            displayName: "Airbus A380",
            aeroflyCode: "a380",
            values: CameraShakeValues(
                kf: 0.95, df: 0.34, kt: 0.0022, dt: 0.0002,
                r0: [31.75, 0.52, 0.765],
                direction: [1.0, 0.0, -0.2]
            ),
            notes: nil
        ),
        CameraShakePreset(
            id: "b747",
            displayName: "Boeing 747-400",
            aeroflyCode: "b747",
            values: CameraShakeValues(
                kf: 0.75, df: 0.2, kt: 1.0022, dt: 1.0002,
                r0: [25.8548, 0.5446, 4.05],
                direction: [1.0, 0.01, -0.23]
            ),
            notes: nil
        ),
        CameraShakePreset(
            id: "b787_9",
            displayName: "Boeing 787-9",
            aeroflyCode: "b787_9",
            values: CameraShakeValues(
                kf: 0.75, df: 0.2, kt: 1.0022, dt: 1.0002,
                r0: [25.8548, 0.5446, 4.05],
                direction: [1.0, 0.01, -0.23]
            ),
            notes: nil
        ),
        CameraShakePreset(
            id: "b777_300er",
            displayName: "Boeing 777-300ER",
            aeroflyCode: "b777_300er",
            values: CameraShakeValues(
                kf: 0.97, df: 0.24, kt: 1.00022, dt: 1.0056,
                r0: [34.32, 0.53, 0.95],
                direction: [1.0, 0.0, -0.25]
            ),
            notes: "Mar17: still tweaking."
        ),
    ]
}
