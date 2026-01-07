//
//  SaveOptionsSection.swift
//  PeekOCR
//
//  Toggle controls for clipboard and file save options.
//

import SwiftUI

/// Section with toggles for save options (clipboard and file)
struct SaveOptionsSection: View {
    @ObservedObject var settings: ScreenshotSettings

    var body: some View {
        Section {
            Toggle("Copiar al portapapeles", isOn: $settings.copyToClipboard)
            Toggle("Guardar como archivo", isOn: $settings.saveToFile)
        } header: {
            Text("Opciones de Guardado")
        } footer: {
            Text("Puedes activar ambas opciones para copiar y guardar al mismo tiempo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Form {
        SaveOptionsSection(settings: ScreenshotSettings.shared)
    }
    .formStyle(.grouped)
}
