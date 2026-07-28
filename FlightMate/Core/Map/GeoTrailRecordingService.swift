//
//  GeoTrailRecordingService.swift
//  FlightMate
//
//  Pure decision logic for MapTrailService: which position observations
//  are worth keeping, and when an in-progress trail should be reset.
//

import Foundation

/// Decides which position observations are worth recording into a trail,
/// and when a trail should start over.
///
/// No state, no I/O, no Combine -- trivially unit testable in isolation
/// from `MapTrailService`, mirroring every other pure-service/
/// stateful-engine split in this codebase (`FlightAnalysisService`/
/// `FlightAnalysisEngine`, `FlightEventDetectionService`/
/// `FlightEventEngine`, `FlightHistoryService`/`FlightHistoryEngine`).
enum GeoTrailRecordingService {
    /// Returns whether `candidate` should be appended to the trail, given
    /// the most recently recorded point (if any).
    ///
    /// A candidate is recorded when it is the very first point, or when
    /// it differs from the last recorded point by at least
    /// `minimumDistanceNauticalMiles` *or* at least
    /// `minimumIntervalSeconds` have elapsed since that point was
    /// recorded -- whichever comes first. This keeps a fast-moving
    /// aircraft's trail dense and a slow/stationary one's trail sparse,
    /// without an unbounded number of near-duplicate points either way.
    static func shouldRecord(
        candidate: GeoTrailPoint,
        lastRecorded: GeoTrailPoint?,
        minimumDistanceNauticalMiles: Double,
        minimumIntervalSeconds: TimeInterval
    ) -> Bool {
        guard let lastRecorded else { return true }

        let distance = GeoDistance.nauticalMiles(from: lastRecorded.coordinate, to: candidate.coordinate)
        if distance >= minimumDistanceNauticalMiles {
            return true
        }

        return candidate.timestamp.timeIntervalSince(lastRecorded.timestamp) >= minimumIntervalSeconds
    }

    /// Returns whether observing `observedHistoryId` (the latest
    /// `FlightHistoryEngine.currentHistory?.id`) should reset the trail,
    /// given the id of the flight currently being recorded (`nil` if
    /// nothing has ever started recording).
    ///
    /// A `nil` `observedHistoryId` (no active flight -- e.g. the moment
    /// just after `flightCompleted`, before the next flight has started)
    /// never resets anything: the just-finished flight's trail stays
    /// visible until a genuinely new one begins. Only a distinct,
    /// non-`nil` id -- a fresh `aircraftLoaded`, or an abort-and-restart
    /// via `aircraftChanged` -- starts a new trail from scratch.
    static func shouldReset(observedHistoryId: UUID?, recordingHistoryId: UUID?) -> Bool {
        guard let observedHistoryId else { return false }
        return observedHistoryId != recordingHistoryId
    }
}
