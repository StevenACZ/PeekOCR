//
//  ScreenshotSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI
import AppKit

/// Screenshot settings tab
struct ScreenshotSettingsTab: View {
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            // Hotkey Section
            Section {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text("Captura de Pantalla")
                        Text("Captura y guarda una imagen del area seleccionada")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(appSettings.screenshotHotKeyDisplayString())
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } header: {
                Text("Atajo de Teclado")
            }

            // Save Options Section
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

            // Save Location Section
            if settings.saveToFile {
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

            // Format Section
            Section {
                Picker("Formato", selection: $settings.imageFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        HStack {
                            Text(format.displayName)
                            Text("(\(format.description))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(format)
                    }
                }

                if settings.imageFormat == .jpg {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Calidad JPG")
                            Spacer()
                            Text("\(Int(settings.imageQuality * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.1)
                    }
                }
            } header: {
                Text("Formato de Imagen")
            }

            // Scale Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tamano de imagen")
                        Spacer()
                        Text("\(Int(settings.imageScale * 100))%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                    }

                    Slider(value: $settings.imageScale, in: 0.1...1.0, step: 0.1)

                    HStack {
                        Text("10%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("50%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("100%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Tamano de Imagen")
            } footer: {
                if settings.imageScale < 1.0 {
                    Text("La imagen se reducira al \(Int(settings.imageScale * 100))% de su tamano original.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("La imagen se guardara a tamano completo (maxima calidad).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Annotations Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Grosor de linea")
                        Spacer()
                        Text("\(Int(appSettings.defaultAnnotationStrokeWidth)) px")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                    }

                    Slider(value: $appSettings.defaultAnnotationStrokeWidth, in: 1...10, step: 1)

                    HStack {
                        Text("1 px")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("5 px")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("10 px")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tamano de fuente")
                        Spacer()
                        Text("\(Int(appSettings.defaultAnnotationFontSize)) pt")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.blue)
                    }

                    Slider(value: $appSettings.defaultAnnotationFontSize, in: 12...48, step: 2)

                    HStack {
                        Text("12 pt")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("30 pt")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("48 pt")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Anotaciones")
            } footer: {
                Text("Estos valores se usaran como predeterminados al abrir el editor de anotaciones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Methods

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

// MARK: - Preview

#Preview {
    ScreenshotSettingsTab()
}
