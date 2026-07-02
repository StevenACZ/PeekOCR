//
//  ShortcutsSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Keyboard shortcuts settings tab.
struct ShortcutsSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var clipSettings = GifClipSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                shortcutsCard
            }
            .padding(16)
        }
    }

    // MARK: - Cards

    private var shortcutsCard: some View {
        SettingsCard(icon: "keyboard", title: "Atajos de teclado") {
            ShortcutRecorderRow(
                title: "Capturar Texto",
                description: "Activa la seleccion de pantalla para OCR",
                icon: "doc.text.viewfinder",
                currentShortcut: settings.captureHotKeyDisplayString(),
                onRecord: { modifiers, keyCode in
                    settings.captureHotKeyModifiers = modifiers
                    settings.captureHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }
            )

            Divider()

            ShortcutRecorderRow(
                title: "Captura de Pantalla",
                description: "Captura una imagen del area seleccionada",
                icon: "camera.viewfinder",
                currentShortcut: settings.screenshotHotKeyDisplayString(),
                onRecord: { modifiers, keyCode in
                    settings.screenshotHotKeyModifiers = modifiers
                    settings.screenshotHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }
            )

            Divider()

            ShortcutRecorderRow(
                title: "Captura con Anotación",
                description: "Overlay vivo: selecciona, ajusta y agrega flechas/texto/highlights antes de capturar",
                icon: "pencil.and.scribble",
                currentShortcut: settings.annotatedScreenshotHotKeyDisplayString(),
                onRecord: { modifiers, keyCode in
                    settings.annotatedScreenshotHotKeyModifiers = modifiers
                    settings.annotatedScreenshotHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }
            )

            Divider()

            ShortcutRecorderRow(
                title: clipSettings.durationLimitEnabled
                    ? "Grabar Clip (\(clipSettings.maxDurationSeconds)s)"
                    : "Grabar Clip",
                description: "Graba un clip o la pantalla completa y lo exporta como GIF o Video",
                icon: "film",
                currentShortcut: settings.gifHotKeyDisplayString(),
                onRecord: { modifiers, keyCode in
                    settings.gifHotKeyModifiers = modifiers
                    settings.gifHotKeyCode = keyCode
                    HotKeyManager.shared.reregisterHotKeys()
                }
            )

            Divider()

            SettingsCaption("Haz clic en \"Grabar\" y presiona la combinación de teclas deseada.")

            SettingsCaption(
                "Nota: algunos atajos como ⌘⇧5/⌘⇧6 pueden estar reservados por macOS. Si no funcionan, desactiva esos atajos en Ajustes del Sistema → Teclado → Atajos de teclado → Capturas de pantalla, o elige otra combinación."
            )

            HStack {
                Spacer()

                Button("Restaurar valores por defecto") {
                    restoreDefaults()
                }
                .controlSize(.small)
            }
        }
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

// MARK: - Preview

#Preview {
    ShortcutsSettingsTab()
}
