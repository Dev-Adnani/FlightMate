//
//  AeroflySessionAircraftReconciler.swift
//  FlightMate
//
//  Merges the live aircraft code from tm.log into a session parsed from
//  main.mcf. When they disagree, tm.log wins — Aerofly can finish loading
//  a new aircraft before rewriting main.mcf, which is how FlightMate can
//  briefly (or longer) show a stale plane such as the default Cessna.
//

import Foundation

enum AeroflySessionAircraftReconciler {
    /// Applies `liveAircraftCode` (from `tm.log`) onto `session`, appending
    /// a validation entry describing what happened.
    static func applyLiveAircraft(
        _ liveAircraftCode: String?,
        to session: inout AeroflySession,
        entries: inout [AeroflySessionValidationEntry]
    ) {
        // No live signal is normal when Aerofly isn't running or tm.log is
        // from an older build — fall back to main.mcf without a warning.
        guard let live = liveAircraftCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !live.isEmpty else {
            return
        }

        if session.aircraft?.aeroflyCode == live {
            entries.append(AeroflySessionValidationEntry(
                field: "aircraft.live",
                status: .found,
                detail: "\(live) (matches main.mcf)"
            ))
            return
        }

        let previous = session.aircraft?.aeroflyCode
        // Livery belongs to the previous aircraft code — drop it on override.
        session.aircraft = AeroflySession.AircraftSelection(aeroflyCode: live, liveryCode: "")
        entries.append(AeroflySessionValidationEntry(
            field: "aircraft",
            status: .found,
            detail: previous.map { "\(live) (tm.log; main.mcf had \($0))" } ?? "\(live) (tm.log)"
        ))
        entries.append(AeroflySessionValidationEntry(
            field: "aircraft.live",
            status: .found,
            detail: "overrode main.mcf"
        ))
    }
}
