//
//  TelemetryService.swift
//  FlightMate
//
//  Owns the live UDP connection to Aerofly FS 4 and publishes raw telemetry
//  packets to the rest of the app.
//

import Combine
import Foundation
import Network

/// Coordinates raw UDP ingestion from Aerofly FS 4 and publishes connection
/// health and raw packets for the rest of the app to consume.
///
/// ## Scope
/// This service deliberately does **not** parse or decode telemetry bytes.
/// It receives datagrams via `UDPListener` and exposes them, unmodified, as
/// an `AsyncStream<Data>` via ``rawPackets``. `FlightContextEngine` consumes
/// that stream, decodes each packet via `TelemetryPacketParser`, and merges
/// the result into a published `FlightContext`.
///
/// ## Configurable port
/// Aerofly FS 4's telemetry port is user-configurable inside the sim, so
/// `start(port:)` always accepts an explicit port rather than assuming
/// ``defaultPort`` is correct for every installation.
///
/// ## Threading
/// This type is `@MainActor`-isolated so its `@Published` properties can be
/// bound directly to SwiftUI views. `UDPListener`'s callbacks arrive on a
/// private background queue and are always hopped onto the main actor
/// before this service mutates any state.
@MainActor
final class TelemetryService: ObservableObject {

    // MARK: - Configuration

    /// The UDP port Aerofly FS 4 sends telemetry to out of the box.
    ///
    /// This is only a *default* value for convenience — it is never
    /// hardcoded into the networking layer itself. Callers may pass any
    /// port to ``start(port:)``, so the listening port can be changed later
    /// (e.g. from a future Settings screen) without any code changes here.
    nonisolated static let defaultPort: UInt16 = 49_002

    // MARK: - Published state (drives the debug UI)

    /// Current health of the UDP listener.
    @Published private(set) var status: TelemetryConnectionStatus = .idle

    /// Total number of raw UDP packets received since the most recent
    /// `start(port:)` call.
    @Published private(set) var packetsReceived: Int = 0

    /// Timestamp of the most recently received packet, if any.
    @Published private(set) var lastPacketDate: Date?

    /// The UDP port currently bound, or most recently requested.
    @Published private(set) var port: UInt16 = TelemetryService.defaultPort

    // MARK: - Raw packet stream

    /// An async sequence of every raw packet received, in order, for the
    /// entire lifetime of this service (independent of individual
    /// `start()`/`stop()` cycles).
    ///
    /// Usage:
    /// ```swift
    /// for await packet in telemetryService.rawPackets {
    ///     // FlightContextEngine decodes `data` here.
    /// }
    /// ```
    ///
    /// - Note: `AsyncStream` delivers each element to exactly one awaiting
    ///   iterator, not to every iterator — this is intentionally treated as
    ///   single-consumer. `FlightContextEngine` is that one consumer;
    ///   anything else that needs live telemetry should read
    ///   `FlightContextEngine`'s published `FlightContext` instead of
    ///   subscribing to raw packets directly.
    let rawPackets: AsyncStream<Data>

    // MARK: - Private

    /// Paired with `rawPackets` via `AsyncStream.makeStream` at init time
    /// (rather than lazily, e.g. inside a computed property), so a packet
    /// can never be dropped due to a consumer starting to iterate
    /// `rawPackets` after data has already started flowing.
    private let packetContinuation: AsyncStream<Data>.Continuation
    private let listener: UDPListener

    /// Resumed the first time the listener reports `.ready` or `.failed`
    /// after a `start(port:)` call, so `start` can be meaningfully awaited
    /// instead of firing-and-forgetting.
    private var startContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Init

    /// - Parameter listener: Injectable for testing. Defaults to a real
    ///   `UDPListener` backed by `Network.framework`.
    init(listener: UDPListener = UDPListener()) {
        self.listener = listener
        (rawPackets, packetContinuation) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .bufferingNewest(64))
        configureListener()
    }

    deinit {
        listener.stop()
        packetContinuation.finish()
    }

    // MARK: - Public API

    /// Starts listening for telemetry on the given UDP port.
    ///
    /// This suspends until the socket is actually bound and ready to
    /// receive (or fails to bind), so callers can reliably know when
    /// listening has begun rather than firing-and-forgetting.
    ///
    /// - Parameter port: Defaults to ``defaultPort`` (49002), but any port
    ///   may be supplied — including a different port on a later call, once
    ///   `stop()` has been called first.
    /// - Throws: `UDPListener.ListenerError` if the port is invalid, a
    ///   listener is already running, or the OS refuses to bind the socket
    ///   (for example, because the port is already in use).
    func start(port: UInt16 = TelemetryService.defaultPort) async throws {
        guard status != .listening, status != .starting else {
            throw UDPListener.ListenerError.alreadyRunning
        }

        self.port = port
        status = .starting
        packetsReceived = 0
        lastPacketDate = nil

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.startContinuation = continuation
            do {
                try self.listener.start(port: port)
            } catch {
                self.status = .failed(error.localizedDescription)
                self.startContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Stops listening. Safe to call even if the service is not currently
    /// running.
    ///
    /// This does *not* finish `rawPackets` — that stream's lifetime matches
    /// this service instance, not individual start/stop cycles, so a
    /// consumer's `for await` loop simply pauses and resumes across
    /// restarts instead of terminating.
    func stop() {
        listener.stop()
        status = .idle
    }

    // MARK: - Wiring UDPListener callbacks onto the main actor

    private func configureListener() {
        listener.onPacketReceived = { [weak self] data in
            Task { @MainActor in
                self?.handlePacket(data)
            }
        }
        listener.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleStateChange(state)
            }
        }
        listener.onFailure = { [weak self] error in
            Task { @MainActor in
                self?.handleFailure(error)
            }
        }
    }

    private func handlePacket(_ data: Data) {
        packetsReceived += 1
        lastPacketDate = Date()
        packetContinuation.yield(data)
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            status = .listening
            startContinuation?.resume()
            startContinuation = nil
        case .failed(let error):
            status = .failed(error.localizedDescription)
            startContinuation?.resume(throwing: error)
            startContinuation = nil
        case .cancelled:
            status = .idle
        default:
            break
        }
    }

    private func handleFailure(_ error: UDPListener.ListenerError) {
        status = .failed(error.localizedDescription)
    }
}
