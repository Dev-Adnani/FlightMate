//
//  FlightContextEngineTests.swift
//  FlightMateTests
//
//  Exercises FlightContextEngine's live wiring to TelemetryService, without
//  any real networking: packets are injected directly through UDPListener's
//  public callback, exactly as Network.framework would invoke it.
//

import Foundation
import Network
import Testing
@testable import FlightMate

@MainActor
struct FlightContextEngineTests {

    @Test func mergesIncomingXGPSPacketIntoPublishedContext() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let engine = FlightContextEngine(telemetryService: telemetryService)

        let payload = Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8)
        listener.onPacketReceived?(payload)

        try await waitUntil { engine.context.latitude != nil }

        #expect(engine.context.latitude == 19.0818)
        #expect(engine.context.longitude == 72.8754)
        #expect(engine.context.altitudeMeters == 11.0)
        #expect(engine.context.groundSpeedMetersPerSecond == 0.2)
        #expect(engine.context.lastUpdated != nil)
    }

    @Test func mergesIncomingXATTPacketIntoPublishedContext() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let engine = FlightContextEngine(telemetryService: telemetryService)

        let payload = Data("XATTAerofly FS 4,314.1,-0.23,0.29".utf8)
        listener.onPacketReceived?(payload)

        try await waitUntil { engine.context.headingDegreesTrue != nil }

        #expect(engine.context.headingDegreesTrue == 314.1)
        #expect(engine.context.pitchDegrees == -0.23)
        #expect(engine.context.rollDegrees == 0.29)
    }

    @Test func accumulatesFieldsAcrossBothPacketTypes() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let engine = FlightContextEngine(telemetryService: telemetryService)

        listener.onPacketReceived?(Data("XGPSAerofly FS 4,72.8754,19.0818,11.0,314.1,0.2".utf8))
        try await waitUntil { engine.context.latitude != nil }

        listener.onPacketReceived?(Data("XATTAerofly FS 4,314.1,-0.23,0.29".utf8))
        try await waitUntil { engine.context.headingDegreesTrue != nil }

        // Both packet types' fields should be present simultaneously.
        #expect(engine.context.latitude == 19.0818)
        #expect(engine.context.headingDegreesTrue == 314.1)
    }

    @Test func ignoresUnknownPacketWithoutChangingContext() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let engine = FlightContextEngine(telemetryService: telemetryService)

        listener.onPacketReceived?(Data("XTRAFFICAerofly FS 4,1,2,3".utf8))

        // Give the (non-)update a moment to (not) happen, then confirm the
        // context is still untouched.
        try await Task.sleep(for: .milliseconds(50))
        #expect(engine.context == .empty)
    }

    @Test func mirrorsTelemetryServiceConnectionStatus() async throws {
        let listener = UDPListener()
        let telemetryService = TelemetryService(listener: listener)
        let engine = FlightContextEngine(telemetryService: telemetryService)

        listener.onStateChange?(.ready)

        try await waitUntil { engine.context.connectionStatus == .listening }
        #expect(engine.context.connectionStatus == .listening)
    }
}

/// Polls `condition` until it becomes `true` or a short timeout elapses.
///
/// `FlightContextEngine` ingests packets and status changes asynchronously
/// (via a background `Task` and a Combine subscription), so tests need a
/// brief, bounded wait for state to propagate rather than asserting
/// immediately after triggering an update.
///
/// `condition` is `@MainActor` because it always closes over `MainActor`-
/// isolated state (`FlightContextEngine.context`); this function itself is
/// `@MainActor` so calling `condition()` never needs an extra `await`.
@MainActor
private func waitUntil(
    timeout: Duration = .milliseconds(500),
    _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for condition to become true.")
}
