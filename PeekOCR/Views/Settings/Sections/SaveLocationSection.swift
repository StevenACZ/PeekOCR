//
//  SaveLocationSection.swift
//  PeekOCR
//
//  Picker for selecting save location with custom folder support.
//

import SwiftUI
import AppKit

/// Section for selecting where to save screenshots
struct SaveLocationSection: View {
    @ObservedObject var settings: ScreenshotSettings

    var body: some View {
        Section {
            Picker("Ubicacion", selection: $settings.saveLocation) {
                ForEach(SaveLocation.allCases) { location in
                    Label(location.displayName, systemImage: location.icon)
                        .tag(location)
                }
            }

            if settings.saveLocation == .custom {
                HStack {
                    Text(settings.customSavePath.isEmpty ? "Ninguna seleccionada" : settings.customSavePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Elegir...") {
                        chooseSaveFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } header: {
            Text("Carpeta de Destino")
        }
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seleccionar"
        panel.message = "Elige la carpeta donde guardar las capturas"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customSavePath = url.path
        }
    }
}

#Preview {
    Form {
        SaveLocationSection(settings: ScreenshotSettings.shared)
    }
    .formStyle(.grouped)
}
