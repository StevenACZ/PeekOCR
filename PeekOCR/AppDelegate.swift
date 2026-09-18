//
//  AppDelegate.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private let hotKeyManager = HotKeyManager.shared
    private var menuBarController: MenuBarStatusController?

    /// The unit tests are hosted by the app; XCTest must not get the status item, the hotkeys, or the updater.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only agent app: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        guard !Self.isRunningTests else { return }

        let controller = MenuBarStatusController()
        controller.start()
        menuBarController = controller

        UpdateManager.shared.start()
        hotKeyManager.registerHotKeys()
        CaptureSoundService.shared.prewarm()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        hotKeyManager.refreshRegistrationIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }
}
