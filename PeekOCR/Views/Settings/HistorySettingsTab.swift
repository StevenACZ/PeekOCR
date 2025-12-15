//
//  HistorySettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// History settings tab
struct HistorySettingsTab: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showClearConfirmation = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Capturas guardadas")
                    Spacer()
                    Text("\(historyManager.items.count) de \(Constants.History.maxItems)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Estado del Historial")
            }
            
            Section {
                if historyManager.items.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.tertiary)
                        Text("El historial está vacío")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(historyManager.items) { item in
                        HistoryItemDetailRow(item: item, historyManager: historyManager)
                    }
                }
            } header: {
                Text("Capturas Recientes")
            }
            
            Section {
                Button("Limpiar Historial", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(historyManager.items.isEmpty)
            }
        }
        .formStyle(.grouped)
        .padding()
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
}

// MARK: - History Item Detail Row

private struct HistoryItemDetailRow: View {
    let item: CaptureItem
    @ObservedObject var historyManager: HistoryManager
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundStyle(item.captureType.displayColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .font(.body)
                    .lineLimit(1)

                HStack {
                    Text(item.captureType.displayLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.captureType.displayColor.opacity(0.1))
                        .foregroundStyle(item.captureType.displayColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(item.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                historyManager.copyItem(item)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copiar")

            Button(role: .destructive) {
                historyManager.removeItem(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Eliminar")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    HistorySettingsTab()
}
