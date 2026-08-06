//
//  CameraShakeTMDPatcherTests.swift
//  FlightMateTests
//

import Foundation
import Testing
@testable import FlightMate

struct CameraShakeTMDPatcherTests {
    private let sample = """
            <[camera_head][CameraPilot][]
                <[string8][Body][Fuselage]>
                <[tmvector3d][R0][ 5.32 0.0 1.21 ]>
                <[tmvector3d][Direction][ 1.0 0.0 -0.1 ]>
                <[float64][Kf][20.0]>
                <[float64][Df][1.00]>
                <[float64][Kt][0.04]>
                <[float64][Dt][0.02]>
                <[bool][InCockpit][true]>
                <[string8][Tags][cockpit pilot]>
            >
            <[camera_head][CameraCopilot][]
                <[float64][Kf][20.0]>
            >
    """

    @Test func patchesOnlyCameraPilotNotCopilot() throws {
        let values = CameraShakeValues(
            kf: 1.45, df: 0.30, kt: 0.0004, dt: 0.0002,
            r0: [5.32, 0.0, 1.30],
            direction: [1.0, 0.0, -0.23]
        )
        let patched = try CameraShakeTMDPatcher.applying(values, to: sample)
        #expect(patched.contains("<[float64][Kf][1.45]>"))
        #expect(patched.contains("<[float64][Df][0.3]>") || patched.contains("<[float64][Df][0.30]>"))
        // Copilot Kf left alone
        let copilotRange = try #require(patched.range(of: "CameraCopilot"))
        let after = patched[copilotRange.lowerBound...]
        #expect(after.contains("<[float64][Kf][20.0]>"))
        #expect(patched.contains("1.3") || patched.contains("1.30"))
    }

    @Test func throwsWhenPilotMissing() {
        #expect(throws: CameraShakeTMDPatcherError.cameraPilotNotFound) {
            _ = try CameraShakeTMDPatcher.applying(
                CameraShakeValues(kf: 1, df: 1, kt: 1, dt: 1),
                to: "<[camera_head][CameraCopilot][]\n<[float64][Kf][1]>\n>"
            )
        }
    }

    @Test func upsertsMissingKfDfIntoParametersStyleBlock() throws {
        let parametersStyle = """
        <[file][][]
            <[modelmanager][][]
                <[pointer_list_tmuniverse][DynamicObjects][]
                    <[camera_head][CameraPilot][]
                        <[tmvector3d][R0][ 16.55 0.51 0.81 ]>
                    >
                >
            >
        >
        """
        let values = CameraShakeValues(kf: 1.25, df: 0.32, kt: 0.04, dt: 0.02)
        let patched = try CameraShakeTMDPatcher.applying(values, to: parametersStyle)
        #expect(patched.contains("<[float64][Kf][1.25]>"))
        #expect(patched.contains("<[float64][Df][0.32]>"))
        #expect(patched.contains("R0"))
    }

    @Test func insertsCameraPilotWhenAbsent() throws {
        let bare = """
        <[file][][]
            <[modelmanager][][]
                <[pointer_list_tmuniverse][DynamicObjects][]
                    <[rigidbody][Fuselage][]
                        <[float64][Mass][1000]>
                    >
                >
            >
        >
        """
        let values = CameraShakeValues(kf: 0.75, df: 0.28, kt: 0.04, dt: 0.02)
        let patched = try CameraShakeTMDPatcher.insertingCameraPilot(values, into: bare)
        #expect(patched.contains("<[camera_head][CameraPilot][]"))
        #expect(patched.contains("<[float64][Kf][0.75]>"))
        #expect(patched.contains("Fuselage"))
    }
}
