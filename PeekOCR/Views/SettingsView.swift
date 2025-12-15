//
//  SettingsView.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Settings window view
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ShortcutsSettingsTab()
                .tabItem {
                    Label("Atajos", systemImage: "keyboard")
                }
            
            TranslationSettingsTab()
                .tabItem {
                    Label("Traducción", systemImage: "globe")
                }
            
            HistorySettingsTab()
                .tabItem {
                    Label("Historial", systemImage: "clock")
                }
            
            AboutTab()
                .tabItem {
                    Label("Acerca de", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
