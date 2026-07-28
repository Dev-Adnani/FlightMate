//
//  DomainResolutionReport.swift
//  FlightMate
//
//  Developer-facing diagnostics produced alongside every
//  DomainResolutionService.resolve(_ session:) call. Mirrors the shape of
//  AeroflySessionValidationReport -- same "field-by-field outcome" idea,
//  applied to reference resolution instead of main.mcf parsing.
//

import Foundation

/// The outcome of resolving a single named field during one
/// `resolve(_ session:)` call.
enum DomainResolutionFieldStatus: Equatable {
    /// Resolved into a full domain object.
    case resolved

    /// An identifier was present but didn't match known reference data --
    /// or the session had no identifier for this field at all (e.g. no
    /// flight plan, so no destination to resolve). Worth a developer's
    /// attention, but not necessarily a bug.
    case missing

    /// No dataset exists yet to resolve this field, regardless of the
    /// identifier (e.g. country, runway today). Informational, not a
    /// warning -- there is nothing actionable for a developer to fix.
    case unavailable
}

/// One diagnostic entry describing the state of a single logical field
/// after a `resolve(_ session:)` attempt.
struct DomainResolutionEntry: Equatable {
    /// A short, stable, human-readable field name, e.g. `"aircraft"`,
    /// `"livery"`, `"departureAirport"`, `"destinationCountry"`.
    let field: String

    let status: DomainResolutionFieldStatus

    /// Free-form detail, e.g. `"a320_neo not found in bundled reference
    /// data"` or `"no flight plan set"`.
    let detail: String?
}

/// A full, developer-facing report of everything `DomainResolutionService`
/// found, didn't find, or couldn't resolve during one
/// `resolve(_ session:)` call.
struct DomainResolutionReport: Equatable {
    let entries: [DomainResolutionEntry]
    let generatedAt: Date

    /// Entries worth a developer's attention -- excludes `.unavailable`,
    /// which is an expected, permanent dataset gap, not something
    /// actionable.
    var warnings: [DomainResolutionEntry] {
        entries.filter { $0.status == .missing }
    }

    /// Known, permanent dataset gaps (e.g. country, runway today) --
    /// surfaced separately from `warnings` so they don't read as bugs.
    var informational: [DomainResolutionEntry] {
        entries.filter { $0.status == .unavailable }
    }

    var hasWarnings: Bool { !warnings.isEmpty }
}
