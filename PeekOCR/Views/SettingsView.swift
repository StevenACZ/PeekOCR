//
//  SettingsView.swift
//  PeekOCR
//
//  Settings window shell: unified-toolbar segmented tabs over keep-alive tab content.
//

import SwiftUI

/// Settings window view.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general
    // Re-renders the whole window when the app language changes.
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            selectedTabContent
        }
        .frame(width: 760, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbarBackground(Color(nsColor: .windowBackgroundColor), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("common.close".localized) {
                    dismiss()
                }
            }
        }
        .tint(Theme.accent)
    }

    /// All tabs stay alive in a ZStack so recorders, scroll positions, and
    /// drafts survive tab switches; selection only flips opacity.
    private var selectedTabContent: some View {
        ZStack {
            tabContent(for: .general) { GeneralSettingsTab() }
            tabContent(for: .shortcuts) { ShortcutsSettingsTab() }
            tabContent(for: .screenshots) { ScreenshotSettingsTab() }
            tabContent(for: .clips) { ClipSettingsTab() }
        }
        .animation(Theme.Anim.easeOut, value: selectedTab)
        // Identity reset: keep-alive tabs skip re-rendering when nothing they
        // observe changes, which would leave their strings in the old language.
        .id(localization.language)
    }

    @ViewBuilder
    private func tabContent<Content: View>(
        for tab: SettingsTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
    }
}

// MARK: - Tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case screenshots
    case clips

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "settings.tabs.general".localized
        case .shortcuts: return "settings.tabs.shortcuts".localized
        case .screenshots: return "settings.tabs.captures".localized
        case .clips: return "settings.tabs.clips".localized
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
