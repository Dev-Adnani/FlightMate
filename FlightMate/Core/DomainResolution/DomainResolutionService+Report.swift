//
//  DomainResolutionService+Report.swift
//  FlightMate
//
//  Builds the field-by-field DomainResolutionReport for one
//  resolve(_ session:) call. Split out from DomainResolutionService.swift
//  purely to keep that file focused on resolution itself.
//

import Foundation

extension DomainResolutionService {
    /// Appends "aircraft" and (when an aircraft selection was present)
    /// "livery" entries describing the outcome of resolving `resolved`.
    func appendAircraftEntries(for resolved: ResolvedAircraft?, into entries: inout [DomainResolutionEntry]) {
        guard let resolved else {
            entries.append(DomainResolutionEntry(
                field: "aircraft",
                status: .missing,
                detail: "no aircraft selection in session"
            ))
            return
        }

        if resolved.aircraft != nil {
            entries.append(DomainResolutionEntry(field: "aircraft", status: .resolved, detail: nil))
        } else {
            entries.append(DomainResolutionEntry(
                field: "aircraft",
                status: .missing,
                detail: "\(resolved.aircraftCode) not found in bundled reference data"
            ))
            // No aircraft to scope a livery lookup to -- nothing more to report.
            return
        }

        if resolved.liveryCode.isEmpty {
            entries.append(DomainResolutionEntry(
                field: "livery",
                status: .missing,
                detail: "no paint scheme recorded in session"
            ))
        } else if resolved.livery != nil {
            entries.append(DomainResolutionEntry(field: "livery", status: .resolved, detail: nil))
        } else {
            entries.append(DomainResolutionEntry(
                field: "livery",
                status: .missing,
                detail: "\(resolved.liveryCode) not found for \(resolved.aircraftCode)"
            ))
        }
    }

    /// Appends "\(fieldPrefix)Airport", "\(fieldPrefix)Runway", and
    /// "\(fieldPrefix)Country" entries describing the outcome of
    /// resolving `resolved`. Runway/country are always reported as
    /// `.unavailable` today, regardless of the airport's own outcome --
    /// no dataset exists for either yet (see `CountryResolving`,
    /// `Runway`).
    func appendAirportEntries(
        for resolved: ResolvedAirport?,
        fieldPrefix: String,
        missingDetail: String,
        into entries: inout [DomainResolutionEntry]
    ) {
        guard let resolved else {
            entries.append(DomainResolutionEntry(
                field: "\(fieldPrefix)Airport",
                status: .missing,
                detail: missingDetail
            ))
            return
        }

        if resolved.airport != nil {
            entries.append(DomainResolutionEntry(field: "\(fieldPrefix)Airport", status: .resolved, detail: nil))
        } else {
            entries.append(DomainResolutionEntry(
                field: "\(fieldPrefix)Airport",
                status: .missing,
                detail: "\(resolved.icaoCode) not found in bundled reference data"
            ))
        }

        entries.append(DomainResolutionEntry(
            field: "\(fieldPrefix)Runway",
            status: .unavailable,
            detail: "no runway dataset bundled yet"
        ))
        entries.append(DomainResolutionEntry(
            field: "\(fieldPrefix)Country",
            status: .unavailable,
            detail: "no country dataset bundled yet"
        ))
    }
}
