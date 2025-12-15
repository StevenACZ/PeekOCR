//
//  ShortcutsSettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI
import Carbon

/// Keyboard shortcuts settings tab
struct ShortcutsSettingsTab: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                ShortcutRecorderRow(
                    title: "Capturar Texto",
                    description: "Activa la selección de pantalla para OCR",
                    icon: "camera.viewfinder",
                    currentShortcut: settings.captureHotKeyDisplayString(),
                    onRecord: { modifiers, keyCode in
                        settings.captureHotKeyModifiers = modifiers
                        settings.captureHotKeyCode = keyCode
                        HotKeyManager.shared.reregisterHotKeys()
                    }
                )
                
                ShortcutRecorderRow(
                    title: "Capturar y Traducir",
                    description: "Captura texto y lo traduce automáticamente",
                    icon: "globe",
                    currentShortcut: settings.translateHotKeyDisplayString(),
                    onRecord: { modifiers, keyCode in
                        settings.translateHotKeyModifiers = modifiers
                        settings.translateHotKeyCode = keyCode
                        HotKeyManager.shared.reregisterHotKeys()
                    }
                )
            } header: {
                Text("Atajos de Teclado")
            } footer: {
                Text("Haz clic en \"Grabar\" y presiona la combinación de teclas deseada.")
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
        settings.translateHotKeyModifiers = AppSettings.Defaults.translateModifiers
        settings.translateHotKeyCode = AppSettings.Defaults.translateKeyCode
        HotKeyManager.shared.reregisterHotKeys()
    }
}

// MARK: - Shortcut Recorder Row

private struct ShortcutRecorderRow: View {
    let title: String
    let description: String
    let icon: String
    let currentShortcut: String
    let onRecord: (UInt32, UInt32) -> Void
    
    @State private var isRecording = false
    @State private var errorMessage: String?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isRecording {
                Text("Presiona una tecla...")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                HStack(spacing: 8) {
                    Text(currentShortcut)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Button("Grabar") {
                        startRecording()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func startRecording() {
        isRecording = true
        
        // Monitor for key events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                let modifiers = convertModifiers(event.modifierFlags)
                let keyCode = UInt32(event.keyCode)
                
                // Require at least one modifier
                if modifiers != 0 {
                    onRecord(modifiers, keyCode)
                    isRecording = false
                }
                
                return nil // Consume the event
            }
            return event
        }
        
        // Cancel on escape or after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isRecording = false
        }
    }
    
    private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}

// MARK: - Preview

#Preview {
    ShortcutsSettingsTab()
}
