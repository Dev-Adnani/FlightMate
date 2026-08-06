//
//  CameraShakeParametersTMDBuilder.swift
//  FlightMate
//
//  Builds a minimal user-folder parameters.tmd that overrides CameraPilot
//  (community approach: Documents/Application Support …/aircraft/…/parameters.tmd).
//

import Foundation

enum CameraShakeParametersTMDBuilder {
    /// Minimal Aerofly parameters.tmd with a CameraPilot override block.
    static func makeFile(values: CameraShakeValues) -> String {
        var lines: [String] = [
            "<[file][][]",
            "    <[modelmanager][][]",
            "        <[pointer_list_tmuniverse][DynamicObjects][]",
            "",
            "            // FlightMate camera shake override (CameraPilot only)",
            "            <[camera_head][CameraPilot][]",
        ]
        if let r0 = values.r0, r0.count == 3 {
            lines.append("                <[tmvector3d][R0][ \(fmt(r0[0])) \(fmt(r0[1])) \(fmt(r0[2])) ]>")
        }
        if let direction = values.direction, direction.count == 3 {
            lines.append(
                "                <[tmvector3d][Direction][ \(fmt(direction[0])) \(fmt(direction[1])) \(fmt(direction[2])) ]>"
            )
        }
        lines.append("                <[float64][Kf][\(fmt(values.kf))]>")
        lines.append("                <[float64][Df][\(fmt(values.df))]>")
        // Kt/Dt included for completeness; Mar17 reports little/no effect when
        // the head is attached to Fuselage.
        lines.append("                <[float64][Kt][\(fmt(values.kt))]>")
        lines.append("                <[float64][Dt][\(fmt(values.dt))]>")
        lines.append(contentsOf: [
            "            >",
            "",
            "        >",
            "    >",
            ">",
            "",
        ])
        return lines.joined(separator: "\n")
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
