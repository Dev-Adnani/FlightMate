//
//  FlightEventEngine.swift
//  FlightMate
//
//  Stateful orchestrator: observes FlightAnalysisEngine's published
//  analysis, threads a small DetectionState across observations, and
//  delegates the actual transition-detection logic to the pure
//  FlightEventDetectionService -- publishing the result as FlightEvent.
//
//  No UI, no AI, no Recorder/Timeline yet -- this milestone only detects
//  and publishes events for future consumers to build on.
//

import Combine
import Foundation

/// Watches `FlightAnalysisEngine.$analysis` over time and publishes
/// discrete `FlightEvent`s whenever a meaningful transition occurs.
///
/// ## Dependency injection
/// Not a singleton. `FlightAnalysisEngine` is a required dependency, and
/// it's the *only* thing this engine consumes -- never `FlightContext`,
/// never raw UDP telemetry, never `main.mcf` -- per this milestone's hard
/// constraint. `now` is injectable for deterministic tests.
///
/// ## How it works
/// Subscribes to `flightAnalysisEngine.$analysis`. On every update, calls
/// `FlightEventDetectionService.detectEvents(previous:current:state:)`
/// with the previously observed analysis (seeded at `.idle`, so an
/// aircraft already known at construction time still fires
/// `.aircraftLoaded` on the very first delivery) and the carried-forward
/// `DetectionState`. Every returned pending event is stamped with a new
/// `UUID`, the current time, and its type's default severity, then
/// published two ways:
/// - `eventPublisher` fires immediately and unconditionally -- the hook
///   a future Flight Recorder taps into to persist every event
///   permanently.
/// - `events` is a bounded, in-memory rolling history (newest last,
///   oldest dropped once `maxHistory` is exceeded). This engine detects
///   events; it deliberately does not become an unbounded database over
///   a multi-hour flight.
@MainActor
final class FlightEventEngine: ObservableObject {
    @Published private(set) var events: [FlightEvent] = []

    var eventPublisher: AnyPublisher<FlightEvent, Never> { eventSubject.eraseToAnyPublisher() }
    private let eventSubject = PassthroughSubject<FlightEvent, Never>()

    private let maxHistory: Int
    private let now: () -> Date

    private var previousAnalysis: FlightAnalysis = .idle
    private var detectionState = FlightEventDetectionService.DetectionState()
    private var cancellable: AnyCancellable?

    /// - Parameters:
    ///   - flightAnalysisEngine: The interpreted flight-state source to
    ///     observe. The sole data dependency of this engine.
    ///   - maxHistory: The maximum number of events `events` retains in
    ///     memory. Defaults to 500; tune down in tests to exercise
    ///     trimming without generating hundreds of samples.
    ///   - now: Injected clock, for deterministic tests.
    init(
        flightAnalysisEngine: FlightAnalysisEngine,
        maxHistory: Int = 500,
        now: @escaping () -> Date = Date.init
    ) {
        self.maxHistory = maxHistory
        self.now = now

        cancellable = flightAnalysisEngine.$analysis
            .sink { [weak self] analysis in
                self?.evaluate(analysis)
            }
    }

    private func evaluate(_ current: FlightAnalysis) {
        let result = FlightEventDetectionService.detectEvents(
            previous: previousAnalysis, current: current, state: detectionState
        )
        detectionState = result.updatedState
        previousAnalysis = current

        for pending in result.events {
            emit(pending.type, analysis: current, metadata: pending.metadata)
        }
    }

    private func emit(_ type: FlightEventType, analysis: FlightAnalysis, metadata: FlightEventMetadata?) {
        let event = FlightEvent(
            eventId: UUID(),
            type: type,
            timestamp: now(),
            analysis: analysis,
            severity: type.defaultSeverity,
            metadata: metadata
        )

        eventSubject.send(event)

        events.append(event)
        if events.count > maxHistory {
            events.removeFirst(events.count - maxHistory)
        }
    }
}
