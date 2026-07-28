//
//  AeroflySessionState.swift
//  FlightMate
//
//  A coarse-grained, structural answer to "why is aeroflySession nil (or
//  stale)?" — deliberately not a generic per-field provenance wrapper, but
//  specific enough that a one-line check answers the question instead of
//  requiring a debugging session.
//

import Foundation

/// The current state of `AeroflySessionService`.
enum AeroflySessionState: Equatable {
    /// `start()` has not been called yet.
    case notStarted

    /// Aerofly's user directory could not be resolved on this system.
    case userDirectoryNotFound

    /// The user directory was found, but `main.mcf` doesn't exist inside
    /// it yet (e.g. Aerofly has never been run, or is mid-restart).
    case fileNotFound

    /// `main.mcf` was found and parsed successfully; `session` reflects
    /// its contents.
    case loaded

    /// `main.mcf` was found, but parsing failed outright. Carries a short
    /// description for logs/debug UI. A far stronger signal than
    /// individual `.unexpected` validation entries — this means the
    /// top-level tree structure itself didn't parse.
    case parseFailed(String)
}
