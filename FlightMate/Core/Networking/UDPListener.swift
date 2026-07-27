//
//  UDPListener.swift
//  FlightMate
//
//  Low-level UDP transport used by TelemetryService to receive live data
//  from Aerofly FS 4.
//

import Foundation
import Network

/// A minimal, transport-only UDP receiver built directly on Apple's
/// `Network.framework`.
///
/// ## Responsibilities
/// `UDPListener` binds a UDP port and receives raw datagrams from *any*
/// sender on the network. It has zero knowledge of Aerofly FS 4's wire
/// format — its only job is to bind, receive bytes, and hand them upward
/// unmodified. Parsing/decoding is intentionally left to a later layer.
///
/// ## Why `NWListener` instead of `NWConnection`?
/// UDP is connectionless, but `Network.framework` still models each unique
/// remote endpoint (Aerofly's host + source port) as a lightweight
/// `NWConnection`, so datagrams can be read with the same `receive` APIs
/// used for TCP. `NWListener.newConnectionHandler` fires once per unique
/// remote endpoint; every subsequent datagram from that same endpoint is
/// then delivered on the associated `NWConnection`.
///
/// ## Interface binding
/// `start(port:)` creates the listener with only a port — no host — which
/// tells the OS to bind across all local interfaces rather than a single
/// hardcoded address such as `127.0.0.1`. This matters because Aerofly FS 4
/// may run on the same Mac (loopback) or on another machine on the local
/// network, and the app must not assume either case.
///
/// ## Thread safety
/// Every `Network.framework` callback for this instance (listener state,
/// connection state, and packet receipt) is funneled through a single
/// private serial `DispatchQueue`. This keeps internal state mutation-safe
/// without needing locks or an actor.
///
/// This project defaults every type to `@MainActor` isolation
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), but `UDPListener` is
/// explicitly `nonisolated`: its callbacks intentionally arrive on a
/// background queue, and `TelemetryService` is responsible for hopping the
/// results back onto the main actor. `@unchecked Sendable` reflects that
/// safety is enforced manually via the serial queue above, not by the
/// Swift concurrency checker.
nonisolated final class UDPListener: @unchecked Sendable {

    // MARK: - Errors

    /// Errors surfaced by `UDPListener`. Every case carries enough context
    /// for a caller to present a useful message or log entry.
    enum ListenerError: Error, LocalizedError {
        /// The requested port could not be represented as a valid UDP port.
        case invalidPort(UInt16)
        /// `start(port:)` was called while a listener was already active.
        case alreadyRunning
        /// The underlying listener or one of its connections failed.
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .invalidPort(let port):
                return "\(port) is not a valid UDP port."
            case .alreadyRunning:
                return "The UDP listener is already running. Call stop() before starting again."
            case .transport(let error):
                return "UDP transport error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Callbacks

    /// Invoked once for every raw datagram received.
    ///
    /// - Important: Called on an internal, private background queue — never
    ///   on the main thread. Callers that need to update UI state must hop
    ///   to the main actor themselves (see `TelemetryService`).
    var onPacketReceived: ((Data) -> Void)?

    /// Invoked whenever the listener's own state transitions
    /// (`.setup` → `.ready`, `.failed`, `.cancelled`, etc.).
    var onStateChange: ((NWListener.State) -> Void)?

    /// Invoked when the listener or one of its per-sender connections fails.
    /// This does not automatically stop the listener; call `stop()` if a
    /// failure should be treated as terminal.
    var onFailure: ((ListenerError) -> Void)?

    // MARK: - Private state

    private var listener: NWListener?

    /// One pseudo-connection per unique remote (host, port) pair that has
    /// sent us a datagram. Keyed by object identity since `NWConnection` is
    /// a reference type without a natural stable key.
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    /// All Network.framework callbacks are scheduled on this single serial
    /// queue, which is what makes mutating `connections` above safe.
    private let queue = DispatchQueue(label: "com.flightmate.udplistener")

    // MARK: - Lifecycle

    /// Starts listening for UDP datagrams on the given port.
    ///
    /// The port is always supplied by the caller — never hardcoded here —
    /// which is what allows `TelemetryService` to expose a configurable
    /// port to the rest of the app.
    ///
    /// - Parameter port: The UDP port to bind. Must be non-zero.
    /// - Throws: `ListenerError.invalidPort` if `port` cannot be represented
    ///   as a valid `NWEndpoint.Port`; `ListenerError.alreadyRunning` if a
    ///   listener is already active; or `ListenerError.transport` if the OS
    ///   refuses to create the listener outright (e.g. the port is already
    ///   in use by another process).
    func start(port: UInt16) throws {
        guard listener == nil else {
            throw ListenerError.alreadyRunning
        }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ListenerError.invalidPort(port)
        }

        let parameters: NWParameters = .udp
        // Allows quick restarts on the same port during development without
        // waiting on the OS to release the previous socket.
        parameters.allowLocalEndpointReuse = true

        let newListener: NWListener
        do {
            // No host is specified, so the OS binds across all local
            // interfaces (loopback + LAN) instead of a single hardcoded
            // address such as "localhost".
            newListener = try NWListener(using: parameters, on: nwPort)
        } catch {
            throw ListenerError.transport(error)
        }

        newListener.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }
        newListener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        listener = newListener
        newListener.start(queue: queue)
    }

    /// Stops listening and tears down every in-flight pseudo-connection.
    /// Safe to call even if the listener was never started.
    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    // MARK: - Listener state

    private func handleStateChange(_ state: NWListener.State) {
        onStateChange?(state)
        if case .failed(let error) = state {
            onFailure?(.transport(error))
        }
    }

    // MARK: - Per-sender connection handling

    /// Accepts a new pseudo-connection representing a distinct remote sender
    /// and begins receiving datagrams from it.
    ///
    /// Every inbound endpoint is accepted unconditionally: Aerofly's host
    /// and source port are not known ahead of time, so the listener cannot
    /// filter by sender at this layer.
    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .failed(let error):
                self?.onFailure?(.transport(error))
                connection?.cancel()
                self?.connections.removeValue(forKey: id)
            case .cancelled:
                self?.connections.removeValue(forKey: id)
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveNextPacket(on: connection)
    }

    /// Reads one datagram and immediately schedules the next read, so the
    /// connection keeps receiving for as long as it stays alive.
    private func receiveNextPacket(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.onPacketReceived?(data)
            }

            if let error {
                self.onFailure?(.transport(error))
                connection?.cancel()
                return
            }

            guard let connection else { return }
            self.receiveNextPacket(on: connection)
        }
    }
}
