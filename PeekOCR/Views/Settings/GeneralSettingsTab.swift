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
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var launchAtLoginEnabled: Bool = LaunchAtLoginManager.shared.isEnabled
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    startupCard
                    languageCard
                    soundCard
                    permissionsCard
                    updatesCard
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
            "settings.general.clear_history_title".localized,
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.clear".localized, role: .destructive) {
                historyManager.clearHistory()
            }

            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("common.cannot_undo".localized)
        }
    }

    // MARK: - Cards

    private var startupCard: some View {
        SettingsCard(icon: "power", title: "settings.general.startup".localized) {
            SettingsToggleRow(
                title: "settings.general.launch_at_login".localized,
                isOn: $launchAtLoginEnabled
            )
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                settings.launchAtLogin = newValue
            }

            SettingsCaption("settings.general.launch_at_login_caption".localized)
        }
    }

    private var languageCard: some View {
        SettingsCard(icon: "globe", title: "settings.general.language".localized) {
            HStack {
                Text("settings.general.app_language".localized)
                    .font(.system(size: 13))

                Spacer()

                Picker("", selection: $localization.language) {
                    Text("Español").tag("es")
                    Text("English").tag("en")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            SettingsCaption("settings.general.language_caption".localized)
        }
    }

    private var soundCard: some View {
        SettingsCard(icon: "speaker.wave.2", title: "settings.general.sound".localized) {
            SettingsToggleRow(
                title: "settings.general.play_capture_sound".localized,
                isOn: $soundSettings.captureSoundEnabled
            )

            Group {
                HStack {
                    Text("settings.general.sound".localized)
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
                    Text("settings.general.volume".localized)
                        .font(.system(size: 13))

                    Slider(value: $soundSettings.captureSoundVolume, in: 0...1)
                        .tint(Theme.accent)

                    Text("\(Int(soundSettings.captureSoundVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, alignment: .trailing)
                }

                SettingsToggleRow(
                    title: "settings.general.ocr_feedback".localized,
                    isOn: $soundSettings.ocrFeedbackEnabled
                )

                Button {
                    CaptureSoundService.shared.preview(soundSettings.captureSound)
                } label: {
                    Label("settings.general.preview_sound".localized, systemImage: "play.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .tint(Theme.accent)
            }
            .disabled(!soundSettings.captureSoundEnabled)
            .opacity(soundSettings.captureSoundEnabled ? 1 : 0.55)

            SettingsCaption("settings.general.sound_caption".localized)
        }
        .animation(Theme.Anim.easeOut, value: soundSettings.captureSoundEnabled)
    }

    private var permissionsCard: some View {
        SettingsCard(icon: "lock.shield", title: "settings.general.permissions".localized) {
            SettingsPermissionsSection()
        }
    }

    private var updatesCard: some View {
        SettingsCard(icon: "arrow.down.circle", title: "settings.general.updates".localized) {
            SettingsToggleRow(
                title: "settings.general.auto_updates".localized,
                isOn: Binding(
                    get: { updateManager.autoCheckEnabled },
                    set: { updateManager.setAutoCheckEnabled($0) }
                )
            )

            SettingsCaption("settings.general.auto_updates_caption".localized)
        }
    }

    private var historyCard: some View {
        SettingsCard(icon: "clock.arrow.circlepath", title: "settings.general.history".localized, fillsHeight: true) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("settings.general.saved_captures".localized)
                        .font(.system(size: 13))

                    Text("settings.general.history_count".localized(historyManager.items.count, Constants.History.maxItems))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("common.clear".localized, role: .destructive) {
                    showClearConfirmation = true
                }
                .controlSize(.small)
                .disabled(historyManager.items.isEmpty)
            }

            if historyManager.items.isEmpty {
                Spacer(minLength: 0)

                EmptyStateView(
                    icon: "tray",
                    message: "settings.general.history_empty".localized,
                    detail: "settings.general.history_empty_detail".localized
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
            .help("common.copy".localized)

            Button(role: .destructive) {
                historyManager.removeItem(item)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("common.delete".localized)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsTab()
}
