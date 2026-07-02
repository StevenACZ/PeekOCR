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
        // Menu-bar-only app: every real window is managed by MenuBarStatusController.
        Settings {
            EmptyView()
        }
    }
}
