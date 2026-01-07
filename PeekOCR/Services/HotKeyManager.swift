//
//  HotKeyManager.swift
//  PeekOCR
//
//  Manages global keyboard shortcuts using Carbon API.
//

import AppKit
import Carbon

/// Manages global keyboard shortcuts for the app
final class HotKeyManager {
    static let shared = HotKeyManager()

    // MARK: - Properties

    private var hotKeyRefs: [HotKeyID: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    func registerHotKeys() {
        requestAccessibilityPermissions()
        installEventHandler()
        registerAllHotKeys()
    }

    func unregisterHotKeys() {
        for (id, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            hotKeyRefs[id] = nil
        }
    }

    func reregisterHotKeys() {
        unregisterHotKeys()
        registerAllHotKeys()
    }

    // MARK: - Private Methods

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

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
                HotKeyManager.shared.handleHotKey(id: hotKeyID.id)
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

    private func handleHotKey(id: UInt32) {
        guard let hotKeyID = HotKeyID(rawValue: id) else { return }

        switch hotKeyID {
        case .capture:
            CaptureCoordinator.shared.startCapture(mode: .ocr)
        case .screenshot:
            CaptureCoordinator.shared.startCapture(mode: .screenshot)
        case .annotated:
            CaptureCoordinator.shared.startCapture(mode: .annotatedScreenshot)
        }
    }

    private func registerAllHotKeys() {
        let settings = AppSettings.shared

        registerHotKey(
            id: .capture,
            keyCode: settings.captureHotKeyCode,
            modifiers: settings.captureHotKeyModifiers
        )

        registerHotKey(
            id: .screenshot,
            keyCode: settings.screenshotHotKeyCode,
            modifiers: settings.screenshotHotKeyModifiers
        )

        registerHotKey(
            id: .annotated,
            keyCode: settings.annotatedScreenshotHotKeyCode,
            modifiers: settings.annotatedScreenshotHotKeyModifiers
        )
    }

    private func registerHotKey(id: HotKeyID, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotKeyDefinition.signature, id: id.rawValue)

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if let ref = ref {
            hotKeyRefs[id] = ref
        }
    }
}
