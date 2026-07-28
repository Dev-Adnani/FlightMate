//
//  AeroflyFileWatching.swift
//  FlightMate
//
//  Protocol seam for watching main.mcf for changes, so AeroflySessionService
//  can be unit-tested without real filesystem timing — mirrors how
//  UDPListener is injected into TelemetryService.
//

import Foundation

/// Watches a single file path for changes and calls back whenever its
/// contents may have changed.
protocol AeroflyFileWatching {
    /// Begins watching `url`. If `url` doesn't exist yet, watches its
    /// parent directory until the file first appears, then transparently
    /// switches to watching the file itself.
    ///
    /// - Parameter onChange: Invoked whenever the watched file may have
    ///   changed (written to, or newly created). Called on an unspecified
    ///   background queue — never assume main-thread delivery.
    func startWatching(_ url: URL, onChange: @escaping () -> Void)

    /// Stops watching and releases any open file handles. Safe to call
    /// even if watching was never started.
    func stopWatching()
}
