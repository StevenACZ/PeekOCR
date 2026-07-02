//
//  GeneralSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI

/// General settings tab.
struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var soundSettings = SoundSettings.shared
    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.shared.isEnabled

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    startupCard
                    permissionsCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    soundCard
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .padding(16)
        }
    }

    // MARK: - Cards

    private var startupCard: some View {
        SettingsCard(icon: "power", title: "Inicio") {
            SettingsToggleRow(
                title: "Iniciar PeekOCR con macOS",
                isOn: $launchAtLoginEnabled
            )
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                settings.launchAtLogin = newValue
            }

            SettingsCaption("La app se iniciará automáticamente cuando enciendas tu Mac.")
        }
    }

    private var permissionsCard: some View {
        SettingsCard(icon: "lock.shield", title: "Permisos") {
            PermissionStatusRow(permission: .screenRecording)

            Divider()

            PermissionStatusRow(permission: .accessibility)

            SettingsCaption(
                "PeekOCR puede guiarte dentro de Ajustes del Sistema y actualizará el estado cuando regreses a la app."
            )
        }
    }

    private var soundCard: some View {
        SettingsCard(icon: "speaker.wave.2", title: "Sonido") {
            SettingsToggleRow(
                title: "Reproducir sonido de captura",
                isOn: $soundSettings.captureSoundEnabled
            )

            Group {
                HStack {
                    Text("Sonido")
                        .font(.system(size: 13))

                    Spacer()

                    Picker("", selection: $soundSettings.captureSound) {
                        ForEach(CaptureSound.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .onChange(of: soundSettings.captureSound) { _, newSound in
                        CaptureSoundService.shared.preview(newSound)
                    }
                }

                HStack {
                    Text("Volumen")
                        .font(.system(size: 13))

                    Slider(value: $soundSettings.captureSoundVolume, in: 0...1)
                        .tint(Theme.accent)

                    Text("\(Int(soundSettings.captureSoundVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, alignment: .trailing)
                }

                SettingsToggleRow(
                    title: "Sonido al copiar texto (OCR)",
                    isOn: $soundSettings.ocrFeedbackEnabled
                )

                Button {
                    CaptureSoundService.shared.preview(soundSettings.captureSound)
                } label: {
                    Label("Probar sonido", systemImage: "play.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .tint(Theme.accent)
            }
            .disabled(!soundSettings.captureSoundEnabled)
            .opacity(soundSettings.captureSoundEnabled ? 1 : 0.55)

            SettingsCaption("Se reproduce al guardar una captura, GIF o video.")
        }
        .animation(Theme.Anim.easeOut, value: soundSettings.captureSoundEnabled)
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsTab()
}
