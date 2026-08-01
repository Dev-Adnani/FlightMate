//
//  FlightPhase+ProcedureContent.swift
//  FlightMate
//
//  Shared parsing between the two places procedure content JSON names a
//  flight phase as a plain string: `ProcedureAutomaticCondition.phase`
//  (single target phase for auto-verification) and
//  `ProcedureSection.applicablePhases` (phase-aware navigation).
//

import Foundation

extension FlightPhase {
    /// Parses a flight-phase name exactly as authored in procedure
    /// content JSON (e.g. `"cruise"`). `FlightPhase` isn't
    /// `RawRepresentable` on its own -- it carries no raw storage worth a
    /// raw type outside of this one content-parsing use case -- so this
    /// is a small explicit initializer instead.
    init?(procedureContentName name: String) {
        switch name {
        case "unknown": self = .unknown
        case "parked": self = .parked
        case "taxi": self = .taxi
        case "takeoff": self = .takeoff
        case "climb": self = .climb
        case "cruise": self = .cruise
        case "descent": self = .descent
        case "approach": self = .approach
        case "landing": self = .landing
        default: return nil
        }
    }
}
