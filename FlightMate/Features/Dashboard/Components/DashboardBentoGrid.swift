//
//  DashboardBentoGrid.swift
//  FlightMate
//
//  Responsive bento layout for the Dashboard: even row heights, intentional
//  spans (wide Navigation/Telemetry next to narrower side cards), and
//  graceful collapse from 3-column → 2-column → 1-column as the window
//  shrinks. Pure layout -- no business logic.
//

import SwiftUI

/// Arranges the seven dashboard cards into a bento grid.
///
/// ## Wide (≥ `Theme.Layout.wideBreakpoint`)
/// ```
/// ┌──────────┬──────────┬──────────┐
/// │ Aircraft │  Phase   │ Duration │
/// ├──────────┴──────────┼──────────┤
/// │     Navigation      │ Connect  │
/// ├─────────────────────┼──────────┤
/// │     Telemetry       │  Events  │
/// └─────────────────────┴──────────┘
/// ```
///
/// ## Medium
/// Two equal columns, Navigation full-width.
///
/// ## Narrow
/// Single column stack -- every card still fills its row evenly.
struct DashboardBentoGrid: View {
    let aircraft: AircraftCardModel
    let flightPhase: FlightPhaseCardModel
    let navigation: NavigationCardModel
    let telemetry: TelemetryCardModel
    let flightDuration: FlightDurationCardModel
    let recentEvents: RecentEventsCardModel
    let connectionStatus: ConnectionStatusCardModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideBento
                .frame(minWidth: Theme.Layout.wideBreakpoint)
            mediumBento
                .frame(minWidth: Theme.Layout.mediumBreakpoint)
            narrowBento
        }
        .frame(maxWidth: Theme.Layout.dashboardMaxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Wide (3-column bento)

    private var wideBento: some View {
        Grid(horizontalSpacing: Theme.Spacing.cardGap, verticalSpacing: Theme.Spacing.cardGap) {
            GridRow {
                AircraftCard(model: aircraft)
                FlightPhaseCard(model: flightPhase)
                FlightDurationCard(model: flightDuration)
            }
            .frame(minHeight: Theme.Layout.bentoHeroRowMinHeight)

            GridRow {
                NavigationCard(model: navigation)
                    .gridCellColumns(2)
                ConnectionStatusCard(model: connectionStatus)
            }
            .frame(minHeight: Theme.Layout.bentoBodyRowMinHeight)

            GridRow {
                TelemetryCard(model: telemetry)
                    .gridCellColumns(2)
                RecentEventsCard(model: recentEvents)
            }
            .frame(minHeight: Theme.Layout.bentoBodyRowMinHeight)
        }
    }

    // MARK: - Medium (2-column)

    private var mediumBento: some View {
        Grid(horizontalSpacing: Theme.Spacing.cardGap, verticalSpacing: Theme.Spacing.cardGap) {
            GridRow {
                AircraftCard(model: aircraft)
                FlightPhaseCard(model: flightPhase)
            }
            .frame(minHeight: Theme.Layout.bentoHeroRowMinHeight)

            GridRow {
                FlightDurationCard(model: flightDuration)
                ConnectionStatusCard(model: connectionStatus)
            }
            .frame(minHeight: Theme.Layout.bentoHeroRowMinHeight)

            GridRow {
                NavigationCard(model: navigation)
                    .gridCellColumns(2)
            }
            .frame(minHeight: Theme.Layout.bentoBodyRowMinHeight)

            GridRow {
                TelemetryCard(model: telemetry)
                RecentEventsCard(model: recentEvents)
            }
            .frame(minHeight: Theme.Layout.bentoBodyRowMinHeight)
        }
    }

    // MARK: - Narrow (1-column)

    private var narrowBento: some View {
        VStack(spacing: Theme.Spacing.cardGap) {
            AircraftCard(model: aircraft)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoHeroRowMinHeight, alignment: .topLeading)
            FlightPhaseCard(model: flightPhase)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoHeroRowMinHeight, alignment: .topLeading)
            FlightDurationCard(model: flightDuration)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoHeroRowMinHeight, alignment: .topLeading)
            NavigationCard(model: navigation)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoBodyRowMinHeight, alignment: .topLeading)
            TelemetryCard(model: telemetry)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoBodyRowMinHeight, alignment: .topLeading)
            RecentEventsCard(model: recentEvents)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoBodyRowMinHeight, alignment: .topLeading)
            ConnectionStatusCard(model: connectionStatus)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.bentoHeroRowMinHeight, alignment: .topLeading)
        }
    }
}

#Preview("Wide") {
    DashboardBentoGrid(
        aircraft: .noSelection,
        flightPhase: .idle,
        navigation: .empty,
        telemetry: .empty,
        flightDuration: .empty,
        recentEvents: .empty,
        connectionStatus: .empty
    )
    .padding()
    .frame(width: 1100, height: 720)
}

#Preview("Medium") {
    DashboardBentoGrid(
        aircraft: .noSelection,
        flightPhase: .idle,
        navigation: .empty,
        telemetry: .empty,
        flightDuration: .empty,
        recentEvents: .empty,
        connectionStatus: .empty
    )
    .padding()
    .frame(width: 780, height: 900)
}
