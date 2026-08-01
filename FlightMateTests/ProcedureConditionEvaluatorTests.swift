//
//  ProcedureConditionEvaluatorTests.swift
//  FlightMateTests
//
//  Pure-function tests for ProcedureConditionEvaluator -- no ViewModel,
//  engines, or telemetry involved, just synthetic FlightContext/
//  FlightAnalysis snapshots.
//

import Testing
@testable import FlightMate

struct ProcedureConditionEvaluatorTests {

    private func context(altitudeMeters: Double? = nil, groundSpeedMetersPerSecond: Double? = nil) -> FlightContext {
        var context = FlightContext.empty
        context.altitudeMeters = altitudeMeters
        context.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
        return context
    }

    private func analysis(phase: FlightPhase) -> FlightAnalysis {
        var analysis = FlightAnalysis.idle
        analysis.flightPhase = phase
        return analysis
    }

    // MARK: - onGround

    @Test func onGroundSatisfiedWhenPhaseIsNotAirborne() {
        let condition = ProcedureAutomaticCondition(kind: .onGround, value: nil, phase: nil)
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .parked)))
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .taxi)))
    }

    @Test func onGroundUnsatisfiedWhenAirborne() {
        let condition = ProcedureAutomaticCondition(kind: .onGround, value: nil, phase: nil)
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .cruise)))
    }

    // MARK: - Altitude thresholds

    @Test func minAltitudeFeetSatisfiedAboveThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .minAltitudeFeet, value: 1000, phase: nil)
        let ctx = context(altitudeMeters: 400) // ~1312 ft
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .climb)))
    }

    @Test func minAltitudeFeetUnsatisfiedBelowThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .minAltitudeFeet, value: 1000, phase: nil)
        let ctx = context(altitudeMeters: 100) // ~328 ft
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .climb)))
    }

    @Test func minAltitudeFeetUnsatisfiedWhenTelemetryMissing() {
        let condition = ProcedureAutomaticCondition(kind: .minAltitudeFeet, value: 1000, phase: nil)
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .climb)))
    }

    @Test func maxAltitudeFeetSatisfiedBelowThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .maxAltitudeFeet, value: 500, phase: nil)
        let ctx = context(altitudeMeters: 50) // ~164 ft
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .descent)))
    }

    @Test func maxAltitudeFeetUnsatisfiedAboveThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .maxAltitudeFeet, value: 500, phase: nil)
        let ctx = context(altitudeMeters: 1000) // ~3281 ft
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .descent)))
    }

    // MARK: - Ground speed thresholds

    @Test func minGroundSpeedKnotsSatisfiedAboveThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .minGroundSpeedKnots, value: 30, phase: nil)
        let ctx = context(groundSpeedMetersPerSecond: 20) // ~38.9 kt
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .takeoff)))
    }

    @Test func maxGroundSpeedKnotsSatisfiedBelowThreshold() {
        let condition = ProcedureAutomaticCondition(kind: .maxGroundSpeedKnots, value: 30, phase: nil)
        let ctx = context(groundSpeedMetersPerSecond: 5) // ~9.7 kt
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: ctx, analysis: analysis(phase: .taxi)))
    }

    @Test func maxGroundSpeedKnotsUnsatisfiedWhenTelemetryMissing() {
        let condition = ProcedureAutomaticCondition(kind: .maxGroundSpeedKnots, value: 30, phase: nil)
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .taxi)))
    }

    // MARK: - flightPhase

    @Test func flightPhaseSatisfiedOnExactMatch() {
        let condition = ProcedureAutomaticCondition(kind: .flightPhase, value: nil, phase: "cruise")
        #expect(ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .cruise)))
    }

    @Test func flightPhaseUnsatisfiedOnMismatch() {
        let condition = ProcedureAutomaticCondition(kind: .flightPhase, value: nil, phase: "cruise")
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .descent)))
    }

    @Test func flightPhaseUnsatisfiedOnUnrecognizedName() {
        let condition = ProcedureAutomaticCondition(kind: .flightPhase, value: nil, phase: "final_approach")
        #expect(!ProcedureConditionEvaluator.isSatisfied(condition, context: .empty, analysis: analysis(phase: .approach)))
    }
}
