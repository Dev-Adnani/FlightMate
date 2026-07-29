//
//  ProceduresViewModel.swift
//  FlightMate
//
//  Navigation state for the guided procedures feature.
//

import Combine
import Foundation

/// Drives aircraft → procedure → overview / step detail. Progress is in-memory only.
@MainActor
final class ProceduresViewModel: ObservableObject {
    enum Screen: Equatable {
        case aircraftList
        case procedureList(aircraftId: String)
        case overview(aircraftId: String, procedureId: String)
        case stepGuide(aircraftId: String, procedureId: String)
    }

    let procedureProvider: ProcedureProviding

    @Published private(set) var screen: Screen = .aircraftList
    @Published private(set) var stepIndex: Int = 0
    /// Step ids the user has marked done on the overview (in-memory).
    @Published private(set) var completedStepIDs: Set<String> = []

    init(procedureProvider: ProcedureProviding) {
        self.procedureProvider = procedureProvider
    }

    var aircraft: [ProcedureAircraft] {
        procedureProvider.allAircraft()
    }

    func procedures(for aircraftId: String) -> [AircraftProcedure] {
        procedureProvider.procedures(for: aircraftId)
    }

    func procedure(aircraftId: String, procedureId: String) -> AircraftProcedure? {
        procedureProvider.procedure(aircraftId: aircraftId, procedureId: procedureId)
    }

    var activeProcedure: AircraftProcedure? {
        switch screen {
        case .overview(let aircraftId, let procedureId),
             .stepGuide(let aircraftId, let procedureId):
            return procedure(aircraftId: aircraftId, procedureId: procedureId)
        default:
            return nil
        }
    }

    var activeSteps: [ProcedureStep] {
        activeProcedure?.allStepsInOrder ?? []
    }

    var currentStep: ProcedureStep? {
        let steps = activeSteps
        guard steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    var currentSectionTitle: String? {
        guard let procedure = activeProcedure,
              let step = currentStep else { return nil }
        return procedure.orderedSections.first { section in
            section.orderedSteps.contains(where: { $0.id == step.id })
        }?.title
    }

    var stepProgressLabel: String {
        let total = activeSteps.count
        guard total > 0 else { return "" }
        return "Step \(stepIndex + 1) of \(total)"
    }

    var completedCount: Int {
        activeSteps.filter { completedStepIDs.contains($0.id) }.count
    }

    var canGoBack: Bool { stepIndex > 0 }

    func selectAircraft(_ id: String) {
        screen = .procedureList(aircraftId: id)
    }

    /// Opens the full procedure as a scannable checklist overview.
    func selectProcedure(aircraftId: String, procedureId: String) {
        stepIndex = 0
        completedStepIDs = []
        screen = .overview(aircraftId: aircraftId, procedureId: procedureId)
    }

    func openStep(at index: Int) {
        guard activeSteps.indices.contains(index),
              case .overview(let aircraftId, let procedureId) = screen else { return }
        stepIndex = index
        screen = .stepGuide(aircraftId: aircraftId, procedureId: procedureId)
    }

    func returnToOverview() {
        switch screen {
        case .stepGuide(let aircraftId, let procedureId),
             .overview(let aircraftId, let procedureId):
            screen = .overview(aircraftId: aircraftId, procedureId: procedureId)
        default:
            break
        }
    }

    func goToAircraftList() {
        screen = .aircraftList
        stepIndex = 0
        completedStepIDs = []
    }

    func goToProcedureList(aircraftId: String) {
        screen = .procedureList(aircraftId: aircraftId)
        stepIndex = 0
        completedStepIDs = []
    }

    func toggleStepCompleted(_ stepId: String) {
        if completedStepIDs.contains(stepId) {
            completedStepIDs.remove(stepId)
        } else {
            completedStepIDs.insert(stepId)
        }
    }

    func isStepCompleted(_ stepId: String) -> Bool {
        completedStepIDs.contains(stepId)
    }

    func advance() {
        let steps = activeSteps
        guard !steps.isEmpty else { return }
        if let step = currentStep {
            completedStepIDs.insert(step.id)
        }
        if stepIndex + 1 < steps.count {
            stepIndex += 1
        } else {
            returnToOverview()
        }
    }

    func goBackStep() {
        guard canGoBack else {
            returnToOverview()
            return
        }
        stepIndex -= 1
    }

    func restartProcedure() {
        guard case .overview(let aircraftId, let procedureId) = screen else { return }
        selectProcedure(aircraftId: aircraftId, procedureId: procedureId)
    }
}
