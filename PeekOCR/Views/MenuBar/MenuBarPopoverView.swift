//
//  MenuBarPopoverView.swift
//  PeekOCR
//
//  Main popover view shown from menu bar with quick actions and history.
//

import SwiftUI

/// Main popover view shown from menu bar
struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var historyManager = HistoryManager.shared
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            HeaderSection()
            Divider()
            QuickActionsSection(settings: settings)
            Divider()
            HistorySection(historyManager: historyManager)
            Divider()
            FooterSection()
        }
        .frame(width: Constants.UI.popoverWidth)
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
            MenuBarActionButton(
                title: "Capturar Texto",
                icon: "doc.text.viewfinder",
                shortcut: settings.captureHotKeyDisplayString()
            ) {
                CaptureCoordinator.shared.startCapture(mode: .ocr)
            }

            MenuBarActionButton(
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
                EmptyStateView()
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
                .frame(maxHeight: Constants.UI.historyMaxHeight)
            }
        }
        .padding(.bottom, 8)
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
