//
//  CameraShakeParametersTMDBuilderTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct CameraShakeParametersTMDBuilderTests {
    @Test func buildsMinimalParametersOverride() {
        let text = CameraShakeParametersTMDBuilder.makeFile(
            values: CameraShakeValues(
                kf: 1.25, df: 0.32, kt: 0.04, dt: 0.02,
                r0: [16.55, 0.51, 0.81],
                direction: [1, 0, -0.21]
            )
        )
        #expect(text.contains("<[camera_head][CameraPilot][]"))
        #expect(text.contains("<[float64][Kf][1.25]>"))
        #expect(text.contains("<[float64][Df][0.32]>"))
        #expect(text.contains("R0"))
        #expect(text.contains("modelmanager"))
    }

    @Test func feelPresetsOrderStiffness() {
        #expect(CameraShakeFeel.softFloating.kfDf.kf < CameraShakeFeel.balanced.kfDf.kf)
        #expect(CameraShakeFeel.balanced.kfDf.kf < CameraShakeFeel.firm.kfDf.kf)
        #expect(CameraShakeFeel.firm.kfDf.kf < CameraShakeFeel.stockLike.kfDf.kf)
    }
}
