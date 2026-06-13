//
//  GeneralSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI

/// General settings tab
struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var soundSettings = SoundSettings.shared
    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.shared.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Iniciar PeekOCR con macOS", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        settings.launchAtLogin = newValue
                    }
            } header: {
                Text("Inicio")
            } footer: {
                Text("La app se iniciará automáticamente cuando enciendas tu Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Reproducir sonido de captura", isOn: $soundSettings.captureSoundEnabled)

                Picker("Sonido", selection: $soundSettings.captureSound) {
                    ForEach(CaptureSound.allCases) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .disabled(!soundSettings.captureSoundEnabled)
                .onChange(of: soundSettings.captureSound) { _, newSound in
                    CaptureSoundService.shared.preview(newSound)
                }

                HStack {
                    Text("Volumen")
                    Slider(value: $soundSettings.captureSoundVolume, in: 0...1)
                        .disabled(!soundSettings.captureSoundEnabled)
                    Text("\(Int(soundSettings.captureSoundVolume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Toggle("Sonido al copiar texto (OCR)", isOn: $soundSettings.ocrFeedbackEnabled)
                    .disabled(!soundSettings.captureSoundEnabled)

                Button("Probar sonido") {
                    CaptureSoundService.shared.preview(soundSettings.captureSound)
                }
                .disabled(!soundSettings.captureSoundEnabled)
            } header: {
                Text("Sonido")
            } footer: {
                Text("Se reproduce al guardar una captura, GIF o video.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Versión")
                    Spacer()
                    Text(Constants.App.version)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Requerimientos")
                    Spacer()
                    Text(Constants.App.minimumOSVersion)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Información")
            }

            Section {
                PermissionStatusRow(
                    permission: .screenRecording
                )

                PermissionStatusRow(
                    permission: .accessibility
                )
            } header: {
                Text("Permisos")
            } footer: {
                Text("PeekOCR puede guiarte dentro de Ajustes del Sistema y actualizará el estado cuando regreses a la app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsTab()
}
