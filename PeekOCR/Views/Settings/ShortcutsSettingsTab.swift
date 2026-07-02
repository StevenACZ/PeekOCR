//
//  ShortcutsSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Carbon
import SwiftUI

/// Keyboard shortcuts tab: one visual tile per capture mode, click the badge to rebind.
struct ShortcutsSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Text("settings.shortcuts.intro".localized)
                .font(.callout)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ShortcutTile(
                    icon: "doc.text.viewfinder",
                    tint: .blue,
                    title: "settings.shortcuts.capture_text".localized,
                    subtitle: "settings.shortcuts.capture_text_subtitle".localized,
                    currentShortcut: settings.captureHotKeyDisplayString()
                ) { modifiers, keyCode in
                    settings.captureHotKeyModifiers = modifiers
                    settings.captureHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }

                ShortcutTile(
                    icon: "camera.viewfinder",
                    tint: .green,
                    title: "settings.shortcuts.screenshot".localized,
                    subtitle: "settings.shortcuts.screenshot_subtitle".localized,
                    currentShortcut: settings.screenshotHotKeyDisplayString()
                ) { modifiers, keyCode in
                    settings.screenshotHotKeyModifiers = modifiers
                    settings.screenshotHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }

                ShortcutTile(
                    icon: "pencil.and.scribble",
                    tint: .purple,
                    title: "settings.shortcuts.annotated".localized,
                    subtitle: "settings.shortcuts.annotated_subtitle".localized,
                    currentShortcut: settings.annotatedScreenshotHotKeyDisplayString()
                ) { modifiers, keyCode in
                    settings.annotatedScreenshotHotKeyModifiers = modifiers
                    settings.annotatedScreenshotHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }

                ShortcutTile(
                    icon: "film",
                    tint: .orange,
                    title: "settings.shortcuts.record_clip".localized,
                    subtitle: "settings.shortcuts.record_clip_subtitle".localized,
                    currentShortcut: settings.gifHotKeyDisplayString()
                ) { modifiers, keyCode in
                    settings.gifHotKeyModifiers = modifiers
                    settings.gifHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }
            }

            VStack(spacing: 10) {
                Text("settings.shortcuts.reserved_note".localized)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button {
                    restoreDefaults()
                } label: {
                    Label("settings.shortcuts.restore_defaults".localized, systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restoreDefaults() {
        settings.captureHotKeyModifiers = AppSettings.Defaults.captureModifiers
        settings.captureHotKeyCode = AppSettings.Defaults.captureKeyCode
        settings.screenshotHotKeyModifiers = AppSettings.Defaults.screenshotModifiers
        settings.screenshotHotKeyCode = AppSettings.Defaults.screenshotKeyCode
        settings.annotatedScreenshotHotKeyModifiers = AppSettings.Defaults.annotatedScreenshotModifiers
        settings.annotatedScreenshotHotKeyCode = AppSettings.Defaults.annotatedScreenshotKeyCode
        settings.gifHotKeyModifiers = AppSettings.Defaults.gifModifiers
        settings.gifHotKeyCode = AppSettings.Defaults.gifKeyCode
        HotKeyManager.shared.reregisterHotKeys()
    }
}

// MARK: - Shortcut Tile

/// Visual capture-mode tile with an inline shortcut recorder badge.
private struct ShortcutTile: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let currentShortcut: String
    let onRecord: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var isHovering = false
    @State private var keyMonitor: Any?
    @State private var recordingTimeoutWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, options: .speed(1.4), value: isHovering)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                HStack(spacing: 5) {
                    if isRecording {
                        Image(systemName: "record.circle")
                            .symbolEffect(.pulse)
                    }

                    Text(isRecording ? "settings.shortcuts.press_keys".localized : currentShortcut)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isRecording ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isRecording ? Color.orange.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(isRecording ? Color.orange : Color.primary)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(isRecording ? "settings.shortcuts.recording_help".localized : "settings.shortcuts.change_help".localized)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isRecording ? tint.opacity(0.4) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1)
        .animation(Theme.Anim.easeOut, value: isHovering)
        .animation(Theme.Anim.spring, value: isRecording)
        .onHover { isHovering = $0 }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        stopRecording()
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else {
                return event
            }

            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async {
                    stopRecording()
                }
                return nil
            }

            let modifiers = HotKeyDisplay.carbonModifiers(from: event.modifierFlags)
            let keyCode = UInt32(event.keyCode)

            // Require at least one modifier
            guard modifiers != 0 else {
                return nil  // Consume the event while recording
            }

            DispatchQueue.main.async {
                stopRecording()
                onRecord(modifiers, keyCode)
            }

            return nil  // Consume the event
        }

        let timeout = DispatchWorkItem {
            stopRecording()
        }
        recordingTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
    }

    private func stopRecording() {
        isRecording = false

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        recordingTimeoutWorkItem?.cancel()
        recordingTimeoutWorkItem = nil
    }
}

// MARK: - Preview

#Preview {
    ShortcutsSettingsTab()
}
