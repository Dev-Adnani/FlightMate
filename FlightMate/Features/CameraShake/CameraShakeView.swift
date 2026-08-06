//
//  CameraShakeView.swift
//  FlightMate
//
//  Apply CameraPilot shake via user-folder parameters.tmd (never Steam).
//

import SwiftUI

struct CameraShakeView: View {
    @StateObject private var viewModel: CameraShakeViewModel

    init(service: CameraShakeApplying = CameraShakeService()) {
        _viewModel = StateObject(wrappedValue: CameraShakeViewModel(service: service))
    }

    var body: some View {
        Form {
            Section {
                Picker("Aircraft", selection: $viewModel.selectedPresetID) {
                    ForEach(viewModel.presets) { preset in
                        Text(preset.displayName).tag(preset.id)
                    }
                }
                .onChange(of: viewModel.selectedPresetID) { _, newID in
                    if let preset = viewModel.presets.first(where: { $0.id == newID }) {
                        viewModel.selectPreset(preset)
                    }
                }

                if let code = viewModel.selectedPreset?.aeroflyCode {
                    LabeledContent("Aerofly code") { Text(code).monospaced() }
                    LabeledContent("User override") {
                        Text(viewModel.hasOverride ? "parameters.tmd present" : "Not applied yet")
                    }
                }
            } header: {
                Text("Aircraft")
            } footer: {
                Text("Writes only to Application Support/Aerofly FS 4/aircraft/<code>/parameters.tmd — the community override path. Steam files stay untouched (IPACS).")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Feel", selection: $viewModel.selectedFeel) {
                    ForEach(CameraShakeFeel.allCases) { feel in
                        Text(feel.title).tag(feel)
                    }
                }
                .onChange(of: viewModel.selectedFeel) { _, feel in
                    viewModel.applyFeel(feel)
                }
                Text(viewModel.selectedFeel.detail)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } header: {
                Text("Touchdown feel (Kf / Df)")
            } footer: {
                Text("From Mar17: lower Kf → heavier floating head (widebodies); higher Df → less bounce. Avoid very low Df (unrealistic springy neck).")
                    .foregroundStyle(.secondary)
            }

            Section("Values") {
                valueRow("Kf", subtitle: "Linear stiffness", value: $viewModel.kf)
                valueRow("Df", subtitle: "Linear damping", value: $viewModel.df)
                Toggle("Also apply R0 + Direction from aircraft preset", isOn: $viewModel.applyR0AndDirection)
                Toggle("Show Kt / Dt (usually ineffective)", isOn: $viewModel.showAdvancedRotation)
                if viewModel.showAdvancedRotation {
                    valueRow("Kt", subtitle: "Rotational stiffness", value: $viewModel.kt)
                    valueRow("Dt", subtitle: "Rotational damping", value: $viewModel.dt)
                    Text("Mar17: changing Kt/Dt from ~0 to 9999 had no noticeable effect when CameraPilot is attached to Fuselage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Apply to user aircraft…") { viewModel.applySelected() }
                        .keyboardShortcut(.defaultAction)
                    Button("Restore backup") { viewModel.restoreSelected() }
                        .disabled(!viewModel.hasOverride)
                    Button("Remove override", role: .destructive) { viewModel.removeOverride() }
                        .disabled(!viewModel.hasOverride)
                }
            } footer: {
                Text("Quit Aerofly before applying; relaunch to feel the change.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Touchdown .wav / SoundObject packs are not automated yet — they need PCM WAV → Aerofly Aircraft Converter → .tsb plus TMD sound triggers (gear compression / multi-threshold). Camera shake alone is what this screen applies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Touchdown sounds")
            }

            if let status = viewModel.statusMessage {
                Section {
                    Text(status)
                        .foregroundStyle(viewModel.statusIsError ? .red : .secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 560)
        .navigationSubtitle("Camera shake")
    }

    private func valueRow(_ title: String, subtitle: String, value: Binding<Double>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            TextField(title, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
        }
    }
}

#Preview {
    CameraShakeView()
}
