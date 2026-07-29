//
//  UDPListener.swift
//  FlightMate
//
//  Low-level UDP transport used by TelemetryService to receive live data
//  from Aerofly FS 4.
//

import Darwin
import Foundation

/// A minimal, transport-only UDP receiver built on BSD sockets.
///
/// ## Responsibilities
/// `UDPListener` binds a UDP port and receives raw datagrams from *any*
/// sender on the network. It has zero knowledge of Aerofly FS 4's wire
/// format — its only job is to bind, receive bytes, and hand them upward
/// unmodified. Parsing/decoding is intentionally left to a later layer.
///
/// ## Why BSD sockets instead of `Network.framework`?
/// Aerofly FS 4 sends ForeFlight-style telemetry as **UDP broadcast**
/// (e.g. to `192.168.x.255:49002`). Apple's `NWListener` models each
/// remote sender as a pseudo-`NWConnection`, which is a poor fit for
/// connectionless broadcast: starting FlightMate while the sim is already
/// transmitting produces a flood of
/// `nw_listener_inbox_accept_udp connect failed [48: Address already in use]`
/// console lines and flaky accepts. Apple DTS guidance for broadcast UDP
/// is to use BSD sockets (`recvfrom`) instead.
///
/// ## Interface binding
/// `start(port:)` binds `INADDR_ANY` (all IPv4 interfaces) so datagrams
/// arrive whether Aerofly is on the same Mac (including broadcast on the
/// LAN interface) or elsewhere on the local network.
///
/// ## Thread safety
/// Socket I/O and state mutation run on a single private serial
/// `DispatchQueue`. Callbacks are invoked on that queue — never the main
/// thread. `TelemetryService` hops results back onto the main actor.
///
/// This project defaults every type to `@MainActor` isolation
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), but `UDPListener` is
/// explicitly `nonisolated`. `@unchecked Sendable` reflects that safety is
/// enforced manually via the serial queue above.
nonisolated final class UDPListener: @unchecked Sendable {

    // MARK: - Errors

    /// Errors surfaced by `UDPListener`. Every case carries enough context
    /// for a caller to present a useful message or log entry.
    enum ListenerError: Error, LocalizedError {
        /// The requested port could not be represented as a valid UDP port.
        case invalidPort(UInt16)
        /// `start(port:)` was called while a listener was already active.
        case alreadyRunning
        /// The underlying socket failed (bind, read, etc.).
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

    /// Distinguishes a fatal, whole-listener failure from a transient
    /// per-datagram read issue. With BSD sockets there is no per-sender
    /// connection object; `.connection` is retained only so existing
    /// `TelemetryService` call sites stay stable and can ignore non-fatal
    /// read glitches without flipping the whole service to `.failed`.
    enum FailureScope {
        /// The listener itself failed. No further packets can be received
        /// until `start(port:)` is called again.
        case listener
        /// A single `recvfrom` failed in a non-fatal way. The socket is
        /// still bound; subsequent datagrams are received normally.
        case connection
    }

    /// Lifecycle of the bound socket, reported via `onStateChange`.
    enum State {
        /// Socket is bound and the read source is active.
        case ready
        /// Bind or setup failed. Associated error is suitable for UI/logging.
        case failed(Error)
        /// `stop()` tore the socket down (or it was never started).
        case cancelled
    }

    // MARK: - Callbacks

    /// Invoked once for every raw datagram received.
    ///
    /// - Important: Called on an internal, private background queue — never
    ///   on the main thread. Callers that need to update UI state must hop
    ///   to the main actor themselves (see `TelemetryService`).
    var onPacketReceived: ((Data) -> Void)?

    /// Invoked whenever the listener's own state transitions
    /// (`.ready`, `.failed`, `.cancelled`).
    var onStateChange: ((State) -> Void)?

    /// Invoked when the listener fails or a non-fatal read error occurs.
    /// This does not automatically stop the listener; call `stop()` if a
    /// failure should be treated as terminal. `scope` tells the caller
    /// which of those two cases this is — see `FailureScope`.
    var onFailure: ((ListenerError, FailureScope) -> Void)?

    // MARK: - Private state

    /// All socket I/O and mutation of the fields below happen on this queue.
    private let queue = DispatchQueue(label: "com.flightmate.udplistener")

    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var isRunning = false

    // MARK: - Lifecycle

    /// Starts listening for UDP datagrams on the given port.
    ///
    /// The port is always supplied by the caller — never hardcoded here —
    /// which is what allows `TelemetryService` to expose a configurable
    /// port to the rest of the app.
    ///
    /// - Parameter port: The UDP port to bind. Must be non-zero.
    /// - Throws: `ListenerError.invalidPort` if `port` is zero;
    ///   `ListenerError.alreadyRunning` if a listener is already active;
    ///   or `ListenerError.transport` if the OS refuses to create or bind
    ///   the socket (e.g. another process already owns the port exclusively).
    func start(port: UInt16) throws {
        try queue.sync {
            guard !isRunning else {
                throw ListenerError.alreadyRunning
            }
            guard port > 0 else {
                throw ListenerError.invalidPort(port)
            }

            let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard fd >= 0 else {
                throw ListenerError.transport(POSIXError(errnoCode))
            }

            // Allow rebinding soon after a previous FlightMate process exits,
            // without waiting for the OS TIME_WAIT-style hold. Deliberately
            // *not* SO_REUSEPORT: sharing the port with a second live process
            // is what produced silent dual-binds and per-packet EADDRINUSE
            // spam under the old NWListener path.
            var reuse: Int32 = 1
            if setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse))) < 0 {
                let error = POSIXError(errnoCode)
                Darwin.close(fd)
                throw ListenerError.transport(error)
            }

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(port.bigEndian)
            address.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

            let bindResult = withUnsafePointer(to: &address) { addressPtr in
                addressPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0 else {
                let error = POSIXError(errnoCode)
                Darwin.close(fd)
                throw ListenerError.transport(error)
            }

            let flags = fcntl(fd, F_GETFL, 0)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
                let error = POSIXError(errnoCode)
                Darwin.close(fd)
                throw ListenerError.transport(error)
            }

            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in
                self?.drainAvailableDatagrams()
            }
            source.setCancelHandler { [weak self] in
                Darwin.close(fd)
                self?.socketFD = -1
            }

            socketFD = fd
            readSource = source
            isRunning = true
            source.resume()
        }

        // Fire outside `queue.sync` so observers can safely call back into
        // `stop()` / `start(port:)` without deadlocking on the same queue.
        onStateChange?(.ready)
    }

    /// Stops listening and closes the socket. Safe to call even if the
    /// listener was never started.
    func stop() {
        queue.sync {
            tearDown(emitCancelled: true)
        }
    }

    // MARK: - Receive loop

    /// Reads every datagram currently queued on the non-blocking socket.
    /// Invoked from the `DispatchSourceRead` event handler on `queue`.
    private func drainAvailableDatagrams() {
        guard socketFD >= 0 else { return }

        var buffer = [UInt8](repeating: 0, count: 65_535)
        while true {
            let received = recvfrom(socketFD, &buffer, buffer.count, 0, nil, nil)
            if received < 0 {
                let code = errno
                if code == EAGAIN || code == EWOULDBLOCK {
                    break
                }
                let error = ListenerError.transport(POSIXError(POSIXError.Code(rawValue: code) ?? .EIO))
                onFailure?(error, .listener)
                onStateChange?(.failed(error))
                tearDown(emitCancelled: false)
                return
            }
            if received == 0 {
                continue
            }
            onPacketReceived?(Data(buffer[0..<received]))
        }
    }

    /// Cancels the read source and clears running state. Must be called on
    /// `queue`. The cancel handler closes the file descriptor.
    private func tearDown(emitCancelled: Bool) {
        guard isRunning || readSource != nil else { return }
        isRunning = false
        readSource?.cancel()
        readSource = nil
        if emitCancelled {
            onStateChange?(.cancelled)
        }
    }

    private var errnoCode: POSIXError.Code {
        POSIXError.Code(rawValue: errno) ?? .EIO
    }
}
