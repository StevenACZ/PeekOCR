//
//  MenuBarPopoverView.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Main popover view shown from menu bar
struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var historyManager = HistoryManager.shared
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSection()
            
            Divider()
            
            // Quick Actions
            QuickActionsSection(settings: settings)
            
            Divider()
            
            // History
            HistorySection(historyManager: historyManager)
            
            Divider()
            
            // Footer
            FooterSection()
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Header Section

private struct HeaderSection: View {
    var body: some View {
        HStack {
            Image(systemName: "eye.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text("PeekOCR")
                .font(.headline)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Quick Actions Section

private struct QuickActionsSection: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 4) {
            ActionButton(
                title: "Capturar Texto",
                icon: "doc.text.viewfinder",
                shortcut: settings.captureHotKeyDisplayString()
            ) {
                CaptureCoordinator.shared.startCapture(mode: .ocr)
            }
            
            ActionButton(
                title: "Captura de Pantalla",
                icon: "camera.viewfinder",
                shortcut: settings.screenshotHotKeyDisplayString()
            ) {
                CaptureCoordinator.shared.startCapture(mode: .screenshot)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let shortcut: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - History Section

private struct HistorySection: View {
    @ObservedObject var historyManager: HistoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                
                Text("Historial")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if historyManager.items.isEmpty {
                EmptyHistoryView()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(historyManager.items) { item in
                            HistoryItemRow(item: item) {
                                historyManager.copyItem(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Empty History View

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            
            Text("No hay capturas recientes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - History Item Row

private struct HistoryItemRow: View {
    let item: CaptureItem
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)
                
                Text(item.displayText)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text(item.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Clic para copiar")
    }
    
    private var iconColor: Color {
        switch item.captureType {
        case .text:
            return .blue
        case .qrCode:
            return .purple
        case .screenshot:
            return .green
        }
    }
}

// MARK: - Footer Section

private struct FooterSection: View {
    @State private var isHoveringSettings = false
    @State private var isHoveringQuit = false
    
    var body: some View {
        HStack {
            settingsButton
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Salir", systemImage: "xmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHoveringQuit ? .primary : .secondary)
            .onHover { hovering in
                isHoveringQuit = hovering
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label("Configuración", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHoveringSettings ? .primary : .secondary)
            .onHover { hovering in
                isHoveringSettings = hovering
            }
        } else {
            Button {
                // Fallback for macOS 13
                if #available(macOS 13.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            } label: {
                Label("Configuración", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHoveringSettings ? .primary : .secondary)
            .onHover { hovering in
                isHoveringSettings = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarPopoverView()
        .environmentObject(AppState.shared)
}
