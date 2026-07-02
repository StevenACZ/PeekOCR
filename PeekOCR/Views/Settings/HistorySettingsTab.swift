//
//  HistorySettingsTab.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// History settings tab.
struct HistorySettingsTab: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusCard
                recentCapturesCard
            }
            .padding(16)
        }
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

    // MARK: - Cards

    private var statusCard: some View {
        SettingsCard(icon: "clock.arrow.circlepath", title: "Estado del historial") {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Capturas guardadas")
                        .font(.system(size: 13))

                    Text("\(historyManager.items.count) de \(Constants.History.maxItems)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Limpiar historial", role: .destructive) {
                    showClearConfirmation = true
                }
                .controlSize(.small)
                .disabled(historyManager.items.isEmpty)
            }
        }
    }

    private var recentCapturesCard: some View {
        SettingsCard(icon: "tray.full", title: "Capturas recientes") {
            if historyManager.items.isEmpty {
                EmptyStateView(icon: "tray", message: "El historial está vacío")
            } else {
                VStack(spacing: 0) {
                    ForEach(historyManager.items) { item in
                        HistoryItemDetailRow(item: item, historyManager: historyManager)

                        if item.id != historyManager.items.last?.id {
                            Divider()
                        }
                    }
                }
                .animation(Theme.Anim.spring, value: historyManager.items.map(\.id))
            }
        }
    }
}

// MARK: - History Item Detail Row

private struct HistoryItemDetailRow: View {
    let item: CaptureItem
    @ObservedObject var historyManager: HistoryManager

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.captureType.displayColor.opacity(0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.captureType.displayColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .font(.system(size: 13))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.captureType.displayLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.captureType.displayColor.opacity(0.1))
                        .foregroundStyle(item.captureType.displayColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text(item.formattedTime)
                        .font(.caption2)
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
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    HistorySettingsTab()
}
