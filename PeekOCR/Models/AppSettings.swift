//
//  AppSettings.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import Carbon
import Combine

/// UserDefaults wrapper for app settings with default values
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let captureHotKeyModifiers = "captureHotKeyModifiers"
        static let captureHotKeyCode = "captureHotKeyCode"
        static let screenshotHotKeyModifiers = "screenshotHotKeyModifiers"
        static let screenshotHotKeyCode = "screenshotHotKeyCode"
        static let launchAtLogin = "launchAtLogin"
    }
    
    // MARK: - Default Values
    
    struct Defaults {
        // Shift + Space for OCR capture
        static let captureModifiers: UInt32 = UInt32(shiftKey)
        static let captureKeyCode: UInt32 = UInt32(kVK_Space)
        
        // Cmd + Shift + 4 for screenshot (like macOS)
        static let screenshotModifiers: UInt32 = UInt32(shiftKey | cmdKey)
        static let screenshotKeyCode: UInt32 = UInt32(kVK_ANSI_4)
        
        static let launchAtLogin = false
        static let maxHistoryItems = Constants.History.maxItems
    }
    
    // MARK: - Hotkey Settings
    
    @Published var captureHotKeyModifiers: UInt32 {
        didSet { defaults.set(captureHotKeyModifiers, forKey: Keys.captureHotKeyModifiers) }
    }
    
    @Published var captureHotKeyCode: UInt32 {
        didSet { defaults.set(captureHotKeyCode, forKey: Keys.captureHotKeyCode) }
    }
    
    @Published var screenshotHotKeyModifiers: UInt32 {
        didSet { defaults.set(screenshotHotKeyModifiers, forKey: Keys.screenshotHotKeyModifiers) }
    }
    
    @Published var screenshotHotKeyCode: UInt32 {
        didSet { defaults.set(screenshotHotKeyCode, forKey: Keys.screenshotHotKeyCode) }
    }
    
    // MARK: - General Settings
    
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        self.captureHotKeyModifiers = UInt32(defaults.integer(forKey: Keys.captureHotKeyModifiers)) != 0
            ? UInt32(defaults.integer(forKey: Keys.captureHotKeyModifiers))
            : Defaults.captureModifiers
        
        self.captureHotKeyCode = UInt32(defaults.integer(forKey: Keys.captureHotKeyCode)) != 0
            ? UInt32(defaults.integer(forKey: Keys.captureHotKeyCode))
            : Defaults.captureKeyCode
        
        self.screenshotHotKeyModifiers = UInt32(defaults.integer(forKey: Keys.screenshotHotKeyModifiers)) != 0
            ? UInt32(defaults.integer(forKey: Keys.screenshotHotKeyModifiers))
            : Defaults.screenshotModifiers
        
        self.screenshotHotKeyCode = UInt32(defaults.integer(forKey: Keys.screenshotHotKeyCode)) != 0
            ? UInt32(defaults.integer(forKey: Keys.screenshotHotKeyCode))
            : Defaults.screenshotKeyCode
        
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
    
    // MARK: - Helpers

    func captureHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: captureHotKeyModifiers, keyCode: captureHotKeyCode)
    }

    func screenshotHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: screenshotHotKeyModifiers, keyCode: screenshotHotKeyCode)
    }
}
