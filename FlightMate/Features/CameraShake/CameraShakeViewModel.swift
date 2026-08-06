//
//  CameraShakeViewModel.swift
//  FlightMate
//

import Combine
import Foundation

@MainActor
final class CameraShakeViewModel: ObservableObject {
    let presets = CameraShakePreset.mar17Forum

    @Published var selectedPresetID: String = CameraShakePreset.mar17Forum.first?.id ?? ""
    @Published var selectedFeel: CameraShakeFeel = .balanced
    @Published var kf: Double = 1.25
    @Published var df: Double = 0.32
    @Published var kt: Double = 0.04
    @Published var dt: Double = 0.02
    @Published var applyR0AndDirection = true
    @Published var showAdvancedRotation = false
    @Published var statusMessage: String?
    @Published var statusIsError = false

    private let service: CameraShakeApplying

    init(service: CameraShakeApplying = CameraShakeService()) {
        self.service = service
        if let first = presets.first {
            loadEditors(from: first)
        }
    }

    var selectedPreset: CameraShakePreset? {
        presets.first { $0.id == selectedPresetID }
    }

    var hasOverride: Bool {
        guard let code = selectedPreset?.aeroflyCode else { return false }
        return service.hasUserOverride(aeroflyCode: code)
    }

    func selectPreset(_ preset: CameraShakePreset) {
        selectedPresetID = preset.id
        loadEditors(from: preset)
        statusMessage = nil
    }

    func applyFeel(_ feel: CameraShakeFeel) {
        selectedFeel = feel
        let pair = feel.kfDf
        kf = pair.kf
        df = pair.df
    }

    func applySelected() {
        guard let preset = selectedPreset else { return }
        var values = CameraShakeValues(kf: kf, df: df, kt: kt, dt: dt, r0: nil, direction: nil)
        if applyR0AndDirection {
            values.r0 = preset.values.r0
            values.direction = preset.values.direction
        }
        do {
            let url = try service.apply(values: values, aeroflyCode: preset.aeroflyCode)
            statusMessage = """
            Wrote user override:
            \(url.path)

            Quit and relaunch Aerofly. Steam install was not modified.
            """
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    func restoreSelected() {
        guard let preset = selectedPreset else { return }
        do {
            if let url = try service.restoreBackup(aeroflyCode: preset.aeroflyCode) {
                statusMessage = "Restored backup to:\n\(url.path)"
                statusIsError = false
            } else {
                statusMessage = "No .bak backup found for this aircraft yet."
                statusIsError = true
            }
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    func removeOverride() {
        guard let preset = selectedPreset else { return }
        do {
            try service.removeUserOverride(aeroflyCode: preset.aeroflyCode)
            statusMessage = "Removed user parameters.tmd override for \(preset.aeroflyCode)."
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func loadEditors(from preset: CameraShakePreset) {
        // Mar17 per-aircraft forum values; Feel picker can override Kf/Df afterward.
        kf = preset.values.kf
        df = preset.values.df
        kt = preset.values.kt
        dt = preset.values.dt
    }
}
