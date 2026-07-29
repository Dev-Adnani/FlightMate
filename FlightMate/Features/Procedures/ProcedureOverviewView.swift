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
    let onToggle: (String) -> Void
    let onOpenStep: (Int) -> Void
    let onBack: () -> Void

    private var flatSteps: [ProcedureStep] { procedure.allStepsInOrder }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            List {
                ForEach(procedure.orderedSections) { section in
                    Section {
                        ForEach(section.orderedSteps) { step in
                            stepRow(step)
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            if section.isOptional {
                                Text("Optional")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
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
                    Text(step.title)
                        .font(Theme.Typography.body.weight(.medium))
                        .foregroundStyle(done ? .secondary : .primary)
                        .strikethrough(done)
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
