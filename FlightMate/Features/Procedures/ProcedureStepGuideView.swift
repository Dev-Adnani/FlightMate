//
//  ProcedureStepGuideView.swift
//  FlightMate
//
//  One guided step: progress, instruction, where, why, expected result.
//

import SwiftUI

struct ProcedureStepGuideView: View {
    let progressLabel: String
    let sectionTitle: String?
    let step: ProcedureStep
    let canGoBack: Bool
    let isLastStep: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sectionGap) {
                    header
                    instructionBlock
                    whereBlock
                    whyBlock
                    expectedBlock
                    if let condition = step.condition, !condition.isEmpty {
                        callout(title: "Only if", text: condition, systemImage: "questionmark.circle")
                    }
                    if let caution = step.caution, !caution.isEmpty {
                        callout(title: "Caution", text: caution, systemImage: "exclamationmark.triangle")
                    }
                    if let notes = step.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                            Text("Notes")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                            ForEach(notes, id: \.self) { note in
                                Text("• \(note)")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.dashboardPadding)
                .frame(maxWidth: Theme.Layout.detailMaxWidth, alignment: .leading)
            }

            Divider()
            controls
                .padding(Theme.Spacing.dashboardPadding)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
            HStack {
                Text(progressLabel)
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.color(for: .informational))
                Spacer()
                Button("Overview", action: onExit)
                    .buttonStyle(.borderless)
            }
            if let sectionTitle {
                Text(sectionTitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Text(step.title)
                .font(Theme.Typography.title)
        }
    }

    private var instructionBlock: some View {
        Text(step.instruction)
            .font(Theme.Typography.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var whereBlock: some View {
        labeledCard(title: "Where", systemImage: "mappin.and.ellipse") {
            Text("\(step.location.panel) → \(step.location.section)")
                .font(Theme.Typography.body.weight(.medium))
            Text(step.location.hint)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var whyBlock: some View {
        labeledCard(title: "Why", systemImage: "lightbulb") {
            Text(step.purpose)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var expectedBlock: some View {
        labeledCard(title: "Expected", systemImage: "eye") {
            ForEach(step.expectedResult, id: \.self) { item in
                Text("• \(item)")
                    .font(Theme.Typography.body)
            }
        }
    }

    private func labeledCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.contentGap) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func callout(title: String, text: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold))
                Text(text).font(Theme.Typography.body)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.secondary)
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.controlCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.contentGap) {
            Button("Back", action: onBack)
                .disabled(!canGoBack)
                .keyboardShortcut(.leftArrow, modifiers: [])

            Spacer()

            Button(isLastStep ? "Complete" : "Next") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: Theme.Layout.detailMaxWidth)
    }
}
