//
//  ProceduresViewModel.swift
//  FlightMate
//
//  Navigation state for the guided procedures feature. Progress
//  (completed step ids) is persisted per-procedure via
//  `ProcedureProgressStoring`, and automatic-verification steps are
//  auto-completed as live telemetry satisfies their condition.
//

import Combine
import Foundation

@MainActor
final class ProceduresViewModel: ObservableObject {
    enum Screen: Equatable {
        case aircraftList
        case procedureList(aircraftId: String)
        case overview(aircraftId: String, procedureId: String)
        case stepGuide(aircraftId: String, procedureId: String)
    }

    let procedureProvider: ProcedureProviding
    private let progressStore: ProcedureProgressStoring

    @Published private(set) var screen: Screen = .aircraftList
    @Published private(set) var stepIndex: Int = 0
    /// Step ids the user (or automatic verification) has marked done for
    /// the active procedure. Persisted to `progressStore` on every change.
    @Published private(set) var completedStepIDs: Set<String> = []
    /// Mirrors the live `FlightAnalysis.flightPhase`, republished so the
    /// overview can highlight a phase-relevant section without the whole
    /// view model needing to observe `FlightAnalysisEngine` directly.
    @Published private(set) var currentFlightPhase: FlightPhase = .unknown

    private var latestContext: FlightContext = .empty
    private var latestAnalysis: FlightAnalysis = .idle
    private var cancellables: Set<AnyCancellable> = []

    init(
        procedureProvider: ProcedureProviding,
        progressStore: ProcedureProgressStoring = ProcedureProgressStore(),
        flightContextEngine: FlightContextEngine,
        flightAnalysisEngine: FlightAnalysisEngine
    ) {
        self.procedureProvider = procedureProvider
        self.progressStore = progressStore
        latestContext = flightContextEngine.context
        latestAnalysis = flightAnalysisEngine.analysis

        flightContextEngine.$context
            .sink { [weak self] context in
                self?.latestContext = context
                self?.evaluateAutomaticSteps()
            }
            .store(in: &cancellables)

        flightAnalysisEngine.$analysis
            .sink { [weak self] analysis in
                self?.latestAnalysis = analysis
                self?.currentFlightPhase = analysis.flightPhase
                self?.evaluateAutomaticSteps()
            }
            .store(in: &cancellables)
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

    private var activeProcedureId: String? {
        switch screen {
        case .overview(_, let procedureId), .stepGuide(_, let procedureId):
            return procedureId
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

    /// The first not-yet-complete, explicitly phase-tagged section that
    /// matches the live flight phase -- i.e. where telemetry suggests the
    /// user actually is right now. `nil` whenever there's nothing useful
    /// to suggest: every matching section is already done, or the
    /// procedure carries no phase tags at all (untagged sections are
    /// always "applicable" but saying so isn't a useful suggestion).
    var suggestedSection: ProcedureSection? {
        guard let procedure = activeProcedure else { return nil }
        return procedure.orderedSections.first { section in
            !section.phases.isEmpty
                && section.isApplicable(to: currentFlightPhase)
                && section.orderedSteps.contains { !completedStepIDs.contains($0.id) }
        }
    }

    func selectAircraft(_ id: String) {
        screen = .procedureList(aircraftId: id)
    }

    /// Opens the full procedure as a scannable checklist overview,
    /// restoring any progress persisted from a previous visit.
    func selectProcedure(aircraftId: String, procedureId: String) {
        stepIndex = 0
        completedStepIDs = progressStore.completedStepIDs(procedureId: procedureId)
        screen = .overview(aircraftId: aircraftId, procedureId: procedureId)
        evaluateAutomaticSteps()
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
        persistProgress()
    }

    func isStepCompleted(_ stepId: String) -> Bool {
        completedStepIDs.contains(stepId)
    }

    func advance() {
        let steps = activeSteps
        guard !steps.isEmpty else { return }
        if let step = currentStep {
            completedStepIDs.insert(step.id)
            persistProgress()
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

    /// Clears all persisted + in-memory progress for the active procedure
    /// and returns to a fresh overview. Backs the overview's "Restart"
    /// action.
    func restartProcedure() {
        guard case .overview(let aircraftId, let procedureId) = screen else { return }
        progressStore.clearProgress(procedureId: procedureId)
        stepIndex = 0
        completedStepIDs = []
        screen = .overview(aircraftId: aircraftId, procedureId: procedureId)
        evaluateAutomaticSteps()
    }

    private func persistProgress() {
        guard let procedureId = activeProcedureId else { return }
        progressStore.setCompletedStepIDs(completedStepIDs, procedureId: procedureId)
    }

    /// Auto-completes any not-yet-done step whose `verification.mode ==
    /// .automatic` and whose `condition` is currently satisfied by live
    /// telemetry. Runs on every context/analysis publish, so it's cheap
    /// by construction -- at most a handful of steps per procedure.
    private func evaluateAutomaticSteps() {
        guard let procedure = activeProcedure else { return }
        var didChange = false
        for step in procedure.allStepsInOrder {
            guard step.verification.mode == .automatic,
                  let condition = step.verification.condition,
                  !completedStepIDs.contains(step.id),
                  ProcedureConditionEvaluator.isSatisfied(condition, context: latestContext, analysis: latestAnalysis)
            else { continue }
            completedStepIDs.insert(step.id)
            didChange = true
        }
        if didChange {
            persistProgress()
        }
    }
}
