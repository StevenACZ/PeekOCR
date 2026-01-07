//
//  HotkeyDisplaySection.swift
//  PeekOCR
//
//  Displays the current hotkey configuration for screenshot capture.
//

import SwiftUI

/// Section displaying the current hotkey for screenshot capture
struct HotkeyDisplaySection: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
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
    }
}

#Preview {
    Form {
        HotkeyDisplaySection(appSettings: AppSettings.shared)
    }
    .formStyle(.grouped)
}
