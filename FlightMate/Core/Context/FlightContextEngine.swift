//
//  FlightContextEngine.swift
//  FlightMate
//
//  Combines raw XGPS/XATT telemetry into one observable FlightContext.
//

import Combine
import Foundation

/// Combines live `XGPS`/`XATT` telemetry into a single, observable
/// `FlightContext` that the rest of the app (Dashboard today; Chat/AI
/// later) can bind to directly.
///
/// ## Dependency injection
/// `FlightContextEngine` is not a singleton. It takes the `TelemetryService`
/// it depends on as an initializer argument, so callers construct and own
/// the instance themselves (see `FlightMateApp`), and tests can supply a
/// `TelemetryService` wired to a fake `UDPListener`.
///
/// ## How it works
/// 1. Subscribes to `telemetryService.$status` to mirror connection health
///    into `context.connectionStatus`, independent of whether any packets
///    are flowing.
/// 2. Consumes `telemetryService.rawPackets` (an `AsyncStream<Data>`) with a
///    long-lived `Task`, decoding each packet via `TelemetryPacketParser`
///    and merging it into `context` via `FlightContext.merging(_:)`.
///
/// The actual merge logic lives on `FlightContext` itself as a pure
/// function, which is what keeps it easy to unit test without any
/// networking involved.
@MainActor
final class FlightContextEngine: ObservableObject {

    /// The latest combined flight context. Updated whenever a new `XGPS` or
    /// `XATT` packet is decoded, or whenever the telemetry connection's
    /// status changes.
    @Published private(set) var context: FlightContext = .empty

    private let telemetryService: TelemetryService
    private var packetConsumerTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    /// - Parameter telemetryService: The telemetry source to observe.
    ///   Injected explicitly — `FlightContextEngine` never reaches for a
    ///   shared/singleton instance.
    init(telemetryService: TelemetryService) {
        self.telemetryService = telemetryService
        context.connectionStatus = telemetryService.status

        observeConnectionStatus()
        observeRawPackets()
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
