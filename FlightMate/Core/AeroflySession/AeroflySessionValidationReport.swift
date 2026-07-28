//
//  AeroflySessionValidationReport.swift
//  FlightMate
//
//  Developer-facing diagnostics produced alongside every AeroflySession
//  parse. Not shown to end users. Its purpose is to make future Aerofly
//  file-format changes immediately visible (via logs/debug UI) instead of
//  silently degrading into missing data with no explanation.
//

import Foundation

/// The outcome of looking up a single field while mapping a parsed
/// `main.mcf` tree into an `AeroflySession`.
enum AeroflySessionFieldStatus: Equatable {
    /// The field was present and parsed successfully.
    case found

    /// The field's containing group was present, but this specific field
    /// was absent. May be entirely expected (e.g. no flight plan set).
    case missing

    /// The field's containing group was present, but its value couldn't
    /// be interpreted as expected (e.g. non-numeric position vector).
    /// Its presence is the strongest signal that Aerofly's file format
    /// has changed.
    case unexpected
}

/// One diagnostic entry describing the state of a single logical field
/// after a parse attempt.
struct AeroflySessionValidationEntry: Equatable {
    /// A short, stable, human-readable field name, e.g. `"aircraft"`,
    /// `"destination"`, `"aeroflyVersion"`.
    let field: String

    let status: AeroflySessionFieldStatus

    /// Free-form detail, e.g. `"no flight plan set"` or the raw value
    /// that failed to parse.
    let detail: String?
}

/// A full, developer-facing report of everything `AeroflySessionMapper`
/// found, didn't find, or couldn't interpret during one parse of
/// `main.mcf` (+ `tm.log` for `aeroflyVersion`).
struct AeroflySessionValidationReport: Equatable {
    let entries: [AeroflySessionValidationEntry]
    let generatedAt: Date

    /// Entries that aren't a clean `.found` — i.e. everything worth a
    /// developer's attention.
    var warnings: [AeroflySessionValidationEntry] {
        entries.filter { $0.status != .found }
    }

    var hasWarnings: Bool { !warnings.isEmpty }
}
