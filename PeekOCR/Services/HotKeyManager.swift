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
    private var translateHotKeyRef: EventHotKeyRef?
    
    private let captureHotKeyID = EventHotKeyID(signature: OSType(0x504B4F43), id: 1) // "PKOC"
    private let translateHotKeyID = EventHotKeyID(signature: OSType(0x504B4F43), id: 2) // "PKOC"
    
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
        
        // Register translate hotkey (Control + Shift + Space by default)
        registerTranslateHotKey()
    }
    
    func unregisterHotKeys() {
        if let captureRef = captureHotKeyRef {
            UnregisterEventHotKey(captureRef)
            captureHotKeyRef = nil
        }
        
        if let translateRef = translateHotKeyRef {
            UnregisterEventHotKey(translateRef)
            translateHotKeyRef = nil
        }
    }
    
    func reregisterHotKeys() {
        unregisterHotKeys()
        registerCaptureHotKey()
        registerTranslateHotKey()
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
                    // Capture hotkey pressed
                    CaptureCoordinator.shared.startCapture(withTranslation: false)
                case 2:
                    // Translate hotkey pressed
                    CaptureCoordinator.shared.startCapture(withTranslation: true)
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
        var hotKeyID = captureHotKeyID
        
        RegisterEventHotKey(
            settings.captureHotKeyCode,
            settings.captureHotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &captureHotKeyRef
        )
    }
    
    private func registerTranslateHotKey() {
        let settings = AppSettings.shared
        var hotKeyID = translateHotKeyID
        
        RegisterEventHotKey(
            settings.translateHotKeyCode,
            settings.translateHotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &translateHotKeyRef
        )
    }
}
