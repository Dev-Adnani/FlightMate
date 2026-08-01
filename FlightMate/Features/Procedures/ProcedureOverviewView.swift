//
//  ProcedureOverviewView.swift
//  FlightMate
//
//  One-screen checklist glimpse: every section and step at a glance.
//

import SwiftUI

struct ProcedureOverviewView: View {
    let procedure: AircraftProcedure
    let completedStepIDs: Set<String>
    let currentFlightPhase: FlightPhase
    let suggestedSectionID: String?
    let onToggle: (String) -> Void
    let onOpenStep: (Int) -> Void
    let onBack: () -> Void
    let onRestart: () -> Void

    @State private var showingRestartConfirmation = false

    private var flatSteps: [ProcedureStep] { procedure.allStepsInOrder }

    private var suggestedSection: ProcedureSection? {
        guard let suggestedSectionID else { return nil }
        return procedure.orderedSections.first { $0.id == suggestedSectionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let suggestedSection {
                suggestionBanner(for: suggestedSection)
            }
            Divider()
            List {
                ForEach(procedure.orderedSections) { section in
                    Section {
                        ForEach(section.orderedSteps) { step in
                            stepRow(step)
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func sectionHeader(_ section: ProcedureSection) -> some View {
        HStack {
            Text(section.title)
            if section.isOptional {
                Text("Optional")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if section.id == suggestedSectionID {
                Label("Now", systemImage: "location.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.color(for: .healthy))
            }
        }
    }

    private func suggestionBanner(for section: ProcedureSection) -> some View {
        HStack(spacing: Theme.Spacing.contentGap) {
            Image(systemName: "location.fill")
                .foregroundStyle(Theme.color(for: .healthy))
            Text("Currently \(currentFlightPhase.displayName.lowercased()) — suggested: \(section.title)")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Jump to it") {
                if let index = flatSteps.firstIndex(where: { step in
                    section.orderedSteps.contains(where: { $0.id == step.id }) && !completedStepIDs.contains(step.id)
                }) {
                    onOpenStep(index)
                }
            }
            .buttonStyle(.borderless)
            .font(Theme.Typography.caption.weight(.semibold))
        }
        .padding(.horizontal, Theme.Spacing.dashboardPadding)
        .padding(.vertical, Theme.Spacing.contentGap / 2)
        .background(Theme.color(for: .healthy).opacity(0.08))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
            HStack {
                Button(action: onBack) {
                    Label("Procedures", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("\(completedCount)/\(flatSteps.count) done")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    showingRestartConfirmation = true
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(completedCount == 0)
                .confirmationDialog(
                    "Restart this checklist?",
                    isPresented: $showingRestartConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Restart", role: .destructive, action: onRestart)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This clears all completed steps for \"\(procedure.title)\".")
                }
            }

            DetailHeader(
                title: procedure.title,
                subtitle: "\(procedure.estimatedMinutes) min · \(procedure.difficulty.rawValue) · tap a row for details"
            )

            Text(procedure.disclaimer)
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(Theme.Spacing.dashboardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var completedCount: Int {
        flatSteps.filter { completedStepIDs.contains($0.id) }.count
    }

    private func stepRow(_ step: ProcedureStep) -> some View {
        let index = flatSteps.firstIndex(where: { $0.id == step.id }) ?? 0
        let done = completedStepIDs.contains(step.id)

        return HStack(alignment: .top, spacing: Theme.Spacing.contentGap) {
            Button {
                onToggle(step.id)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Theme.color(for: .healthy) : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(done ? "Mark not done" : "Mark done")

            Button {
                onOpenStep(index)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(step.title)
                            .font(Theme.Typography.body.weight(.medium))
                            .foregroundStyle(done ? .secondary : .primary)
                            .strikethrough(done)
                        if step.verification.mode == .automatic {
                            Text("Auto")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                    Text(step.location.panel)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                    if let condition = step.condition, !condition.isEmpty {
                        Text(condition)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
