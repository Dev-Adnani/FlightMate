//
//  DashboardCard.swift
//  FlightMate
//
//  The shared contract every top-level Dashboard card conforms to.
//

import SwiftUI

/// Marker protocol for every card shown in `DashboardView`'s grid.
///
/// This does not use type erasure or a runtime registry -- `DashboardView`
/// still lists its cards explicitly, since SwiftUI's `@ViewBuilder`-based
/// grids are simplest when concretely typed, and the dashboard's card set
/// changes far less often than any one card's content. What this protocol
/// buys instead: a documented, consistent shape (a `cardTitle`/`cardIcon`
/// identity rendered through `CardContainer`) that every future card
/// (Weather, AI Copilot, Checklist Progress, Flight Recorder, Statistics)
/// is expected to follow. Adding one of those is: create a new `View`
/// conforming to `DashboardCard`, wrap its body in `CardContainer`, and add
/// one line to `DashboardView`'s grid -- never a change to
/// `CardContainer`, `DashboardViewModel`'s wiring pattern, or the grid's
/// layout logic itself.
protocol DashboardCard: View {
    var cardTitle: String { get }
    var cardIcon: String { get }
}
