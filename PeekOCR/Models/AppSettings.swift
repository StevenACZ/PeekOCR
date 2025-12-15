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
        static let maxHistoryItems = 6
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
        return hotKeyDisplayString(modifiers: captureHotKeyModifiers, keyCode: captureHotKeyCode)
    }
    
    func screenshotHotKeyDisplayString() -> String {
        return hotKeyDisplayString(modifiers: screenshotHotKeyModifiers, keyCode: screenshotHotKeyCode)
    }
    
    private func hotKeyDisplayString(modifiers: UInt32, keyCode: UInt32) -> String {
        var parts: [String] = []
        
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        
        // Add key name
        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_0: return "0"
        default: return nil
        }
    }
}
