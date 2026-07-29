//
//  ProceduresView.swift
//  FlightMate
//
//  Guided procedures: aircraft → procedure overview → optional step detail.
//

import SwiftUI

struct ProceduresView: View {
    @StateObject private var viewModel: ProceduresViewModel

    init(procedureProvider: ProcedureProviding) {
        _viewModel = StateObject(wrappedValue: ProceduresViewModel(procedureProvider: procedureProvider))
    }

    var body: some View {
        Group {
            switch viewModel.screen {
            case .aircraftList:
                aircraftList
            case .procedureList(let aircraftId):
                procedureList(aircraftId: aircraftId)
            case .overview:
                if let procedure = viewModel.activeProcedure {
                    ProcedureOverviewView(
                        procedure: procedure,
                        completedStepIDs: viewModel.completedStepIDs,
                        onToggle: { viewModel.toggleStepCompleted($0) },
                        onOpenStep: { viewModel.openStep(at: $0) },
                        onBack: {
                            if case .overview(let aircraftId, _) = viewModel.screen {
                                viewModel.goToProcedureList(aircraftId: aircraftId)
                            }
                        }
                    )
                } else {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "Missing procedure",
                        message: "Could not load this procedure."
                    )
                }
            case .stepGuide:
                if let step = viewModel.currentStep {
                    ProcedureStepGuideView(
                        progressLabel: viewModel.stepProgressLabel,
                        sectionTitle: viewModel.currentSectionTitle,
                        step: step,
                        canGoBack: viewModel.canGoBack,
                        isLastStep: viewModel.stepIndex + 1 >= viewModel.activeSteps.count,
                        onBack: { viewModel.goBackStep() },
                        onNext: { viewModel.advance() },
                        onExit: { viewModel.returnToOverview() }
                    )
                } else {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "No steps",
                        message: "This procedure has no steps yet."
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Procedures")
    }

    private var aircraftList: some View {
        Group {
            if viewModel.aircraft.isEmpty {
                EmptyStateView(
                    systemImage: "checklist",
                    title: "No procedures yet",
                    message: "Guided procedures will appear here as aircraft content is added."
                )
            } else {
                List(viewModel.aircraft) { aircraft in
                    Button {
                        viewModel.selectAircraft(aircraft.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(aircraft.name)
                                .font(Theme.Typography.section)
                                .foregroundStyle(.primary)
                            Text("\(aircraft.manufacturer) · \(aircraft.supportedProcedures.count) procedure\(aircraft.supportedProcedures.count == 1 ? "" : "s")")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func procedureList(aircraftId: String) -> some View {
        let procedures = viewModel.procedures(for: aircraftId)
        let name = viewModel.procedureProvider.aircraft(id: aircraftId)?.name ?? aircraftId

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    viewModel.goToAircraftList()
                } label: {
                    Label("Aircraft", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.dashboardPadding)
            .padding(.top, Theme.Spacing.contentGap)

            if procedures.isEmpty {
                EmptyStateView(
                    systemImage: "checklist",
                    title: "No procedures",
                    message: "No guided procedures are bundled for this aircraft yet."
                )
            } else {
                List(procedures) { procedure in
                    Button {
                        viewModel.selectProcedure(aircraftId: aircraftId, procedureId: procedure.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(procedure.title)
                                .font(Theme.Typography.section)
                                .foregroundStyle(.primary)
                            Text("\(procedure.totalStepCount) steps · ~\(procedure.estimatedMinutes) min · \(procedure.difficulty.rawValue)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationSubtitle(name)
    }
}

#Preview {
    ProceduresView(procedureProvider: ProcedureService())
}
