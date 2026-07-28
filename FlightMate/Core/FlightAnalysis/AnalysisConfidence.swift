//
//  AnalysisConfidence.swift
//  FlightMate
//
//  How confident FlightAnalysisService currently is in its own output,
//  alongside the reasons why -- so a future AI layer knows whether to
//  answer confidently or say "I'm not certain."
//

import Foundation

/// A qualitative confidence level for the current `FlightAnalysis`, paired
/// with the human-readable factors that produced it.
struct AnalysisConfidence: Equatable {
    /// Deliberately binary today, matching the factors currently
    /// available (aircraft resolution, nearest-airport knowledge,
    /// telemetry freshness). `level` is always recomputed fresh from
    /// those same factors, so a future, more granular scale (e.g. a
    /// `.medium` tier) can be introduced later without changing any call
    /// site.
    enum Level: Equatable {
        case high
        case low
    }

    let level: Level

    /// Human-readable, checkmark-style factors explaining `level` -- e.g.
    /// `["Aircraft resolved", "Nearest airport known", "Fresh telemetry"]`
    /// when `.high`, or `["Aircraft unknown", "Telemetry stale"]` when
    /// `.low`.
    let reasons: [String]
}
