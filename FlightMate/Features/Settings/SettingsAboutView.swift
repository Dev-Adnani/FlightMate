//
//  SettingsAboutView.swift
//  FlightMate
//
//  Honest About pane — preferences that don't exist yet are not listed.
//

import SwiftUI

struct SettingsAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                DetailHeader(
                    title: "FlightMate",
                    subtitle: "Native macOS companion for Aerofly FS 4"
                )

                Text("Live telemetry, flight analysis, and reference browsers for aircraft and airports. AI instructor and preference panes will appear here when those systems ship.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                    Text("Working now")
                        .font(Theme.Typography.section)
                    bullet("Dashboard — live flight summary")
                    bullet("Moving Map — position and trail")
                    bullet("Aircraft & Airports — bundled reference browsers")
                    bullet("Flight History — takeoff-to-landing timeline")
                    bullet("Developer — diagnostics for the Core pipeline")
                }
            }
            .padding(Theme.Spacing.dashboardPadding)
            .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("About")
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .foregroundStyle(.tertiary)
            Text(text)
                .font(Theme.Typography.body)
        }
    }
}

#Preview {
    SettingsAboutView()
}
