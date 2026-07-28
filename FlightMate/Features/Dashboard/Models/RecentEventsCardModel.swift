//
//  RecentEventsCardModel.swift
//  FlightMate
//
//  Lightweight, Equatable display model for RecentEventsCard, derived
//  entirely from FlightEventEngine.events. RecentEventsCard never touches
//  FlightEventEngine/FlightEvent directly -- only this model.
//

import Foundation

/// One row in `RecentEventsCard`.
struct EventRowModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let systemImage: String
    let timestamp: Date
    let severityLevel: HealthLevel
}

/// Everything `RecentEventsCard` needs to render, and nothing else.
struct RecentEventsCardModel: Equatable {
    /// Newest first -- ready to render top-to-bottom with no further
    /// sorting by the view.
    let rows: [EventRowModel]

    static let empty = RecentEventsCardModel(rows: [])

    /// `events` is `FlightEventEngine.events`, which is ordered oldest
    /// first (newest last) and already bounded -- see its own doc
    /// comment. This only takes the most recent `limit` and reverses them
    /// for display; it never re-sorts or re-derives anything about the
    /// events themselves.
    static func from(events: [FlightEvent], limit: Int = 6) -> RecentEventsCardModel {
        let rows = events.suffix(limit).reversed().map { event in
            EventRowModel(
                id: event.eventId,
                title: event.type.displayName,
                systemImage: event.type.systemImage,
                timestamp: event.timestamp,
                severityLevel: event.severity.healthLevel
            )
        }
        return RecentEventsCardModel(rows: Array(rows))
    }
}
