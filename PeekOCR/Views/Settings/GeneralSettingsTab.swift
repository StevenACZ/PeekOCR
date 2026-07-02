//
//  GeneralSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI

/// General settings tab: startup, sound, permissions, and history management.
struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var soundSettings = SoundSettings.shared
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.shared.isEnabled
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    startupCard
                    soundCard
                    permissionsCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                historyCard
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            // Column 2 stretches to column 1's height (history card fills it).
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
        }
        .confirmationDialog(
            "¿Limpiar todo el historial?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Limpiar", role: .destructive) {
                historyManager.clearHistory()
            }

            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
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

    private var historyCard: some View {
        SettingsCard(icon: "clock.arrow.circlepath", title: "Historial", fillsHeight: true) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Capturas guardadas")
                        .font(.system(size: 13))

                    Text("\(historyManager.items.count) de \(Constants.History.maxItems)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Limpiar", role: .destructive) {
                    showClearConfirmation = true
                }
                .controlSize(.small)
                .disabled(historyManager.items.isEmpty)
            }

            if historyManager.items.isEmpty {
                Spacer(minLength: 0)

                EmptyStateView(
                    icon: "tray",
                    message: "El historial está vacío",
                    detail: "Tus capturas recientes aparecerán aquí"
                )

                Spacer(minLength: 0)
            } else {
                Divider()

                VStack(spacing: 0) {
                    ForEach(historyManager.items) { item in
                        HistoryManagementRow(item: item, historyManager: historyManager)

                        if item.id != historyManager.items.last?.id {
                            Divider()
                        }
                    }
                }
                .animation(Theme.Anim.spring, value: historyManager.items.map(\.id))

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - History Management Row

private struct HistoryManagementRow: View {
    let item: CaptureItem
    @ObservedObject var historyManager: HistoryManager

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.captureType.displayColor.opacity(0.14))
                    .frame(width: 24, height: 24)

                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.captureType.displayColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayText)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Button {
                historyManager.copyItem(item)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copiar")

            Button(role: .destructive) {
                historyManager.removeItem(item)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Eliminar")
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsTab()
}
