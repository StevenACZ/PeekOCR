//
//  MenuBarPopoverView.swift
//  PeekOCR
//
//  Menu bar panel: header, capture history, and app actions.
//

import SwiftUI

/// Bridges the popover hosting controller with the SwiftUI panel content.
struct MenuBarPanelHost: View {
    let openSettings: () -> Void
    let openAbout: () -> Void
    let quit: () -> Void

    var body: some View {
        MenuBarPopoverView(openSettings: openSettings, openAbout: openAbout, quit: quit)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Main panel shown from the menu bar status item.
struct MenuBarPopoverView: View {
    let openSettings: () -> Void
    let openAbout: () -> Void
    let quit: () -> Void

    @ObservedObject private var historyManager = HistoryManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var missingPermissions: [AppPermission] = []

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            if !missingPermissions.isEmpty {
                PermissionSummaryBanner(missingPermissions: missingPermissions) {
                    PermissionRequirementsWindowController.shared.showWindow()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()
            }

            historySection
                .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 16)

            ActionRow(
                icon: "gearshape",
                title: "Configuración",
                subtitle: "Atajos, capturas, clips e historial",
                action: openSettings
            )

            Divider()
                .padding(.horizontal, 16)

            ActionRow(icon: "info.circle", title: "Acerca de PeekOCR", action: openAbout)

            Divider()
                .padding(.horizontal, 16)

            ActionRow(icon: "power", title: "Salir de PeekOCR", isDestructive: true, action: quit)
                .padding(.bottom, 4)
        }
        .frame(width: Theme.Layout.panelWidth)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshMissingPermissions)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            refreshMissingPermissions()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("PeekOCR")
                    .font(.headline)

                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .animation(Theme.Anim.easeOut, value: statusLine)

            Spacer()

            HotkeyBadge(text: settings.captureHotKeyDisplayString())
                .help("Atajo para capturar texto")
        }
    }

    private var statusLine: String {
        if !missingPermissions.isEmpty {
            return "Permisos pendientes"
        }
        switch historyManager.items.count {
        case 0:
            return "Listo para capturar"
        case 1:
            return "1 captura en el historial"
        case let count:
            return "\(count) capturas en el historial"
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Historial")
                .padding(.horizontal, 16)

            if historyManager.items.isEmpty {
                EmptyStateView(
                    detail: "Usa \(settings.captureHotKeyDisplayString()) para capturar texto"
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(historyManager.items) { item in
                        HistoryItemRow(item: item) {
                            historyManager.copyItem(item)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.15), value: historyManager.items.map(\.id))
            }
        }
    }

    private func refreshMissingPermissions() {
        missingPermissions = PermissionService.shared.missingPermissions()
    }
}

// MARK: - Preview

#Preview {
    MenuBarPanelHost(openSettings: {}, openAbout: {}, quit: {})
}
