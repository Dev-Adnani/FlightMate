//
//  DomainResolutionStatus.swift
//  FlightMate
//
//  Shared resolution-outcome enum used by every composite domain object
//  produced by DomainResolutionService (ResolvedAircraft, ResolvedAirport).
//

import Foundation

/// Coarse-grained outcome of resolving a composite domain object from a raw
/// Aerofly identifier (or pair of identifiers).
///
/// Always derived as a **computed** property from the object's own stored,
/// optional fields -- never stored separately -- so it can never drift out
/// of sync with the data it describes.
enum DomainResolutionStatus: Equatable {
    /// Every constituent piece resolved into a full domain object.
    case resolved

    /// The primary identifier resolved, but at least one secondary piece
    /// (e.g. a livery code) did not.
    case partial

    /// The primary identifier itself did not resolve into anything known.
    case unresolved
}
