//
//  PeekOCRApp.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

@main
struct PeekOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Settings window accessible from menu
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}
