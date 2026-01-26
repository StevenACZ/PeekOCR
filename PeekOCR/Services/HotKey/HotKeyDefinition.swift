//
//  HotKeyDefinition.swift
//  PeekOCR
//
//  Configuration struct for hotkey registration with key code and modifiers.
//

import Carbon

/// Defines a hotkey configuration for registration
struct HotKeyDefinition {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let action: () -> Void

    /// Creates an EventHotKeyID for Carbon registration
    var eventHotKeyID: EventHotKeyID {
        EventHotKeyID(signature: HotKeyDefinition.signature, id: id)
    }

    /// Shared signature for all PeekOCR hotkeys ("PKOC")
    static let signature: OSType = OSType(0x504B4F43)
}

/// Predefined hotkey identifiers
enum HotKeyID: UInt32 {
    case capture = 1        // OCR capture
    case screenshot = 2     // Screenshot
    case annotated = 3      // Annotated screenshot
    case gif = 4            // GIF clip recording
}
