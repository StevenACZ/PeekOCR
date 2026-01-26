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
        static let annotatedScreenshotHotKeyModifiers = "annotatedScreenshotHotKeyModifiers"
        static let annotatedScreenshotHotKeyCode = "annotatedScreenshotHotKeyCode"
        static let gifHotKeyModifiers = "gifHotKeyModifiers"
        static let gifHotKeyCode = "gifHotKeyCode"
        static let launchAtLogin = "launchAtLogin"
        static let defaultAnnotationStrokeWidth = "defaultAnnotationStrokeWidth"
        static let defaultAnnotationFontSize = "defaultAnnotationFontSize"
    }

    // MARK: - Default Values

    struct Defaults {
        // Shift + Space for OCR capture
        static let captureModifiers: UInt32 = UInt32(shiftKey)
        static let captureKeyCode: UInt32 = UInt32(kVK_Space)

        // Cmd + Shift + 4 for screenshot (like macOS)
        static let screenshotModifiers: UInt32 = UInt32(shiftKey | cmdKey)
        static let screenshotKeyCode: UInt32 = UInt32(kVK_ANSI_4)

        // Cmd + Shift + 5 for annotated screenshot
        static let annotatedScreenshotModifiers: UInt32 = UInt32(shiftKey | cmdKey)
        static let annotatedScreenshotKeyCode: UInt32 = UInt32(kVK_ANSI_5)

        // Cmd + Shift + 6 for GIF recording (user can change in settings)
        static let gifModifiers: UInt32 = UInt32(shiftKey | cmdKey)
        static let gifKeyCode: UInt32 = UInt32(kVK_ANSI_6)

        static let launchAtLogin = false
        static let maxHistoryItems = Constants.History.maxItems

        // Annotation defaults
        static let annotationStrokeWidth: Double = 3.0
        static let annotationFontSize: Double = 16.0
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

    @Published var annotatedScreenshotHotKeyModifiers: UInt32 {
        didSet { defaults.set(annotatedScreenshotHotKeyModifiers, forKey: Keys.annotatedScreenshotHotKeyModifiers) }
    }

    @Published var annotatedScreenshotHotKeyCode: UInt32 {
        didSet { defaults.set(annotatedScreenshotHotKeyCode, forKey: Keys.annotatedScreenshotHotKeyCode) }
    }

    @Published var gifHotKeyModifiers: UInt32 {
        didSet { defaults.set(gifHotKeyModifiers, forKey: Keys.gifHotKeyModifiers) }
    }

    @Published var gifHotKeyCode: UInt32 {
        didSet { defaults.set(gifHotKeyCode, forKey: Keys.gifHotKeyCode) }
    }

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    // MARK: - Annotation Settings

    @Published var defaultAnnotationStrokeWidth: Double {
        didSet { defaults.set(defaultAnnotationStrokeWidth, forKey: Keys.defaultAnnotationStrokeWidth) }
    }

    @Published var defaultAnnotationFontSize: Double {
        didSet { defaults.set(defaultAnnotationFontSize, forKey: Keys.defaultAnnotationFontSize) }
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

        self.annotatedScreenshotHotKeyModifiers = UInt32(defaults.integer(forKey: Keys.annotatedScreenshotHotKeyModifiers)) != 0
            ? UInt32(defaults.integer(forKey: Keys.annotatedScreenshotHotKeyModifiers))
            : Defaults.annotatedScreenshotModifiers

        self.annotatedScreenshotHotKeyCode = UInt32(defaults.integer(forKey: Keys.annotatedScreenshotHotKeyCode)) != 0
            ? UInt32(defaults.integer(forKey: Keys.annotatedScreenshotHotKeyCode))
            : Defaults.annotatedScreenshotKeyCode

        self.gifHotKeyModifiers = UInt32(defaults.integer(forKey: Keys.gifHotKeyModifiers)) != 0
            ? UInt32(defaults.integer(forKey: Keys.gifHotKeyModifiers))
            : Defaults.gifModifiers

        self.gifHotKeyCode = UInt32(defaults.integer(forKey: Keys.gifHotKeyCode)) != 0
            ? UInt32(defaults.integer(forKey: Keys.gifHotKeyCode))
            : Defaults.gifKeyCode

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Load annotation settings with defaults
        let savedStrokeWidth = defaults.double(forKey: Keys.defaultAnnotationStrokeWidth)
        self.defaultAnnotationStrokeWidth = savedStrokeWidth > 0 ? savedStrokeWidth : Defaults.annotationStrokeWidth

        let savedFontSize = defaults.double(forKey: Keys.defaultAnnotationFontSize)
        self.defaultAnnotationFontSize = savedFontSize > 0 ? savedFontSize : Defaults.annotationFontSize
    }

    // MARK: - Helpers

    func captureHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: captureHotKeyModifiers, keyCode: captureHotKeyCode)
    }

    func screenshotHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: screenshotHotKeyModifiers, keyCode: screenshotHotKeyCode)
    }

    func annotatedScreenshotHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: annotatedScreenshotHotKeyModifiers, keyCode: annotatedScreenshotHotKeyCode)
    }

    func gifHotKeyDisplayString() -> String {
        HotKeyDisplay.displayString(modifiers: gifHotKeyModifiers, keyCode: gifHotKeyCode)
    }
}
