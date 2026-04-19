//
//  GeneralSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI
import AppKit

/// General settings tab
struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var soundSettings = SoundSettings.shared
    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.shared.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Iniciar PeekOCR con macOS", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { newValue in
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

                HStack {
                    Text("Volumen")
                    Slider(value: $soundSettings.captureSoundVolume, in: 0...1)
                        .disabled(!soundSettings.captureSoundEnabled)
                    Text("\(Int(soundSettings.captureSoundVolume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Button("Probar sonido") {
                    CaptureSoundService.shared.play()
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
                    title: "Grabar Pantalla",
                    description: "Necesario para capturar texto",
                    icon: "rectangle.dashed.badge.record",
                    checkPermission: checkScreenCapturePermission,
                    openSettings: openScreenCaptureSettings
                )

                PermissionStatusRow(
                    title: "Accesibilidad",
                    description: "Necesario para atajos globales",
                    icon: "accessibility",
                    checkPermission: checkAccessibilityPermission,
                    openSettings: openAccessibilitySettings
                )
            } header: {
                Text("Permisos")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Permission Checks

    private func checkScreenCapturePermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func openScreenCaptureSettings() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsTab()
}
