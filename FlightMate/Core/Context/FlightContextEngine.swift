//
//  FlightContextEngine.swift
//  FlightMate
//
//  Combines raw XGPS/XATT telemetry into one observable FlightContext.
//

import Combine
import Foundation

/// Combines live UDP telemetry (`XGPS`/`XATT`) with the Aerofly session
/// file (`main.mcf`, via `AeroflySessionService`) into a single, observable
/// `FlightContext` that the rest of the app (Dashboard today; Chat/AI
/// later) can bind to directly.
///
/// ## Dependency injection
/// `FlightContextEngine` is not a singleton. It takes both the
/// `TelemetryService` and `AeroflySessionService` it depends on as
/// initializer arguments, so callers construct and own the instances
/// themselves (see `FlightMateApp`), and tests can supply fakes for either.
///
/// ## How it works
/// 1. Subscribes to `telemetryService.$status` to mirror connection health
///    into `context.connectionStatus`, independent of whether any packets
///    are flowing.
/// 2. Consumes `telemetryService.rawPackets` (an `AsyncStream<Data>`) with a
///    long-lived `Task`, decoding each packet via `TelemetryPacketParser`
///    and merging it into `context` via `FlightContext.merging(_:)`.
/// 3. Independently subscribes to `aeroflySessionService`'s `$session`,
///    `$state`, and `$lastValidationReport` and mirrors them into
///    `context` verbatim. This is a completely separate code path from
///    (2) — UDP parsing is never touched by session updates, and vice
///    versa, per `FlightContext`'s documented source-precedence rule.
///
/// The actual telemetry merge logic lives on `FlightContext` itself as a
/// pure function, which is what keeps it easy to unit test without any
/// networking involved.
@MainActor
final class FlightContextEngine: ObservableObject {

    /// The latest combined flight context. Updated whenever a new `XGPS` or
    /// `XATT` packet is decoded, whenever the telemetry connection's status
    /// changes, or whenever the Aerofly session is reparsed.
    @Published private(set) var context: FlightContext = .empty

    private let telemetryService: TelemetryService
    private let aeroflySessionService: AeroflySessionService
    private var packetConsumerTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    /// - Parameters:
    ///   - telemetryService: The UDP telemetry source to observe.
    ///   - aeroflySessionService: The `main.mcf` session source to observe.
    ///     Both are injected explicitly — `FlightContextEngine` never
    ///     reaches for a shared/singleton instance.
    init(telemetryService: TelemetryService, aeroflySessionService: AeroflySessionService) {
        self.telemetryService = telemetryService
        self.aeroflySessionService = aeroflySessionService
        context.connectionStatus = telemetryService.status
        context.aeroflySession = aeroflySessionService.session
        context.aeroflySessionState = aeroflySessionService.state
        context.aeroflySessionValidation = aeroflySessionService.lastValidationReport

        observeConnectionStatus()
        observeRawPackets()
        observeAeroflySession()
    }

    deinit {
        packetConsumerTask?.cancel()
    }

    // MARK: - Connection status

    private func observeConnectionStatus() {
        telemetryService.$status
            .sink { [weak self] status in
                self?.context.connectionStatus = status
            }
            .store(in: &cancellables)
    }

    // MARK: - Aerofly session

    private func observeAeroflySession() {
        aeroflySessionService.$session
            .sink { [weak self] session in
                self?.context.aeroflySession = session
            }
            .store(in: &cancellables)

        aeroflySessionService.$state
            .sink { [weak self] state in
                self?.context.aeroflySessionState = state
            }
            .store(in: &cancellables)

        aeroflySessionService.$lastValidationReport
            .sink { [weak self] report in
                self?.context.aeroflySessionValidation = report
            }
            .store(in: &cancellables)
    }

    // MARK: - Packet ingestion

    private func observeRawPackets() {
        packetConsumerTask = Task { [weak self] in
            guard let self else { return }
            for await packet in self.telemetryService.rawPackets {
                guard !Task.isCancelled else { break }
                self.handle(packet)
            }
        }
    }

    private func handle(_ data: Data) {
        guard let decoded = TelemetryPacketParser.parse(data) else {
            // Unknown/malformed packets are already logged by the parser;
            // FlightContext simply has nothing new to merge.
            return
        }
        context = context.merging(decoded)
    }
}
