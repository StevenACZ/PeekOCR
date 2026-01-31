//
//  ShortcutsSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Keyboard shortcuts settings tab
struct ShortcutsSettingsTab: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var clipSettings = GifClipSettings.shared

    var body: some View {
        Form {
            Section {
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

                ShortcutRecorderRow(
                    title: "Captura con Anotacion",
                    description: "Captura y abre el editor de anotaciones",
                    icon: "pencil.and.scribble",
                    currentShortcut: settings.annotatedScreenshotHotKeyDisplayString(),
                    onRecord: { modifiers, keyCode in
                        settings.annotatedScreenshotHotKeyModifiers = modifiers
                        settings.annotatedScreenshotHotKeyCode = keyCode
                        HotKeyManager.shared.reregisterHotKeys()
                    }
                )

                ShortcutRecorderRow(
                    title: "Grabar Clip (\(clipSettings.maxDurationSeconds)s)",
                    description: "Graba un clip corto y lo exporta como GIF o Video",
                    icon: "film",
                    currentShortcut: settings.gifHotKeyDisplayString(),
                    onRecord: { modifiers, keyCode in
                        settings.gifHotKeyModifiers = modifiers
                        settings.gifHotKeyCode = keyCode
                        HotKeyManager.shared.reregisterHotKeys()
                    }
                )
            } header: {
                Text("Atajos de Teclado")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Haz clic en \"Grabar\" y presiona la combinacion de teclas deseada.")
                    Text("Nota: algunos atajos como ⌘⇧5/⌘⇧6 pueden estar reservados por macOS. Si no funcionan, desactiva esos atajos en Ajustes del Sistema → Teclado → Atajos de teclado → Capturas de pantalla, o elige otra combinacion.")
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restaurar Valores Por Defecto") {
                    restoreDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
