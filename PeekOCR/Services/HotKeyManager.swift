//
//  HotKeyManager.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import Carbon

/// Manages global keyboard shortcuts for the app
final class HotKeyManager {
    static let shared = HotKeyManager()

    // MARK: - Properties

    private var captureHotKeyRef: EventHotKeyRef?
    private var screenshotHotKeyRef: EventHotKeyRef?
    private var annotatedScreenshotHotKeyRef: EventHotKeyRef?

    private let captureHotKeyID = EventHotKeyID(signature: OSType(0x504B4F43), id: 1) // "PKOC"
    private let screenshotHotKeyID = EventHotKeyID(signature: OSType(0x504B4F43), id: 2) // "PKOC"
    private let annotatedScreenshotHotKeyID = EventHotKeyID(signature: OSType(0x504B4F43), id: 3) // "PKOC"

    private var eventHandler: EventHandlerRef?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    func registerHotKeys() {
        // Request accessibility permissions
        requestAccessibilityPermissions()

        // Install event handler
        installEventHandler()

        // Register capture hotkey (Shift + Space by default)
        registerCaptureHotKey()

        // Register screenshot hotkey (Cmd + Shift + 4 by default)
        registerScreenshotHotKey()

        // Register annotated screenshot hotkey (Cmd + Shift + 5 by default)
        registerAnnotatedScreenshotHotKey()
    }

    func unregisterHotKeys() {
        if let captureRef = captureHotKeyRef {
            UnregisterEventHotKey(captureRef)
            captureHotKeyRef = nil
        }

        if let screenshotRef = screenshotHotKeyRef {
            UnregisterEventHotKey(screenshotRef)
            screenshotHotKeyRef = nil
        }

        if let annotatedScreenshotRef = annotatedScreenshotHotKeyRef {
            UnregisterEventHotKey(annotatedScreenshotRef)
            annotatedScreenshotHotKeyRef = nil
        }
    }

    func reregisterHotKeys() {
        unregisterHotKeys()
        registerCaptureHotKey()
        registerScreenshotHotKey()
        registerAnnotatedScreenshotHotKey()
    }

    // MARK: - Private Methods

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1:
                    // Capture hotkey pressed (OCR)
                    CaptureCoordinator.shared.startCapture(mode: .ocr)
                case 2:
                    // Screenshot hotkey pressed
                    CaptureCoordinator.shared.startCapture(mode: .screenshot)
                case 3:
                    // Annotated screenshot hotkey pressed
                    CaptureCoordinator.shared.startCapture(mode: .annotatedScreenshot)
                default:
                    break
                }
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }

    private func registerCaptureHotKey() {
        let settings = AppSettings.shared
        let hotKeyID = captureHotKeyID

        RegisterEventHotKey(
            settings.captureHotKeyCode,
            settings.captureHotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &captureHotKeyRef
        )
    }

    private func registerScreenshotHotKey() {
        let settings = AppSettings.shared
        let hotKeyID = screenshotHotKeyID

        RegisterEventHotKey(
            settings.screenshotHotKeyCode,
            settings.screenshotHotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &screenshotHotKeyRef
        )
    }

    private func registerAnnotatedScreenshotHotKey() {
        let settings = AppSettings.shared
        let hotKeyID = annotatedScreenshotHotKeyID

        RegisterEventHotKey(
            settings.annotatedScreenshotHotKeyCode,
            settings.annotatedScreenshotHotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &annotatedScreenshotHotKeyRef
        )
    }
}
