//
//  ProcedureProgressStore.swift
//  FlightMate
//
//  Persists which steps of a guided procedure the user has already
//  completed, so progress survives navigating away (aircraft list,
//  another procedure) and app restarts. Deliberately a small,
//  UserDefaults-backed key/value store rather than a SwiftData model --
//  a `Set<String>` of step ids per procedure has no relational structure
//  worth a schema.
//

import Foundation

protocol ProcedureProgressStoring: AnyObject {
    /// Step ids the user has already marked complete for `procedureId`,
    /// across all aircraft (procedure ids are already globally unique --
    /// see the Knowledge bundle's resource-naming rule).
    func completedStepIDs(procedureId: String) -> Set<String>

    /// Overwrites the persisted completed-step set for `procedureId`.
    func setCompletedStepIDs(_ stepIDs: Set<String>, procedureId: String)

    /// Clears all persisted progress for `procedureId` -- backs the
    /// "Restart" action.
    func clearProgress(procedureId: String)
}

final class ProcedureProgressStore: ProcedureProgressStoring {
    private static let keyPrefix = "com.flightmate.procedureProgress."

    private let userDefaults: UserDefaults

    /// - Parameter userDefaults: Injected so this store can be unit
    ///   tested against an isolated suite rather than the shared one.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func completedStepIDs(procedureId: String) -> Set<String> {
        guard let stored = userDefaults.array(forKey: key(for: procedureId)) as? [String] else { return [] }
        return Set(stored)
    }

    func setCompletedStepIDs(_ stepIDs: Set<String>, procedureId: String) {
        userDefaults.set(Array(stepIDs), forKey: key(for: procedureId))
    }

    func clearProgress(procedureId: String) {
        userDefaults.removeObject(forKey: key(for: procedureId))
    }

    private func key(for procedureId: String) -> String {
        Self.keyPrefix + procedureId
    }
}
