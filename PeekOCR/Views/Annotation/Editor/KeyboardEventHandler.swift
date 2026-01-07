//
//  KeyboardEventHandler.swift
//  PeekOCR
//
//  Handles keyboard events for annotation editor (shortcuts, undo, save, etc.).
//

import AppKit

/// Handles keyboard shortcuts for the annotation editor
final class KeyboardEventHandler {
    private var keyMonitor: Any?
    private weak var state: AnnotationState?
    private var onSave: (() -> Void)?
    private var onCancel: (() -> Void)?

    // MARK: - Setup

    /// Sets up the keyboard monitor
    /// - Parameters:
    ///   - state: The annotation state to modify
    ///   - onSave: Callback when save is triggered
    ///   - onCancel: Callback when cancel is triggered
    func setup(state: AnnotationState, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.state = state
        self.onSave = onSave
        self.onCancel = onCancel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    /// Removes the keyboard monitor
    func teardown() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let state = state else { return false }

        // If text input is active, only handle Escape
        if state.isTextInputActive {
            if event.keyCode == KeyCode.escape {
                state.cancelTextInput()
                return true
            }
            return false
        }

        let characters = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags

        // Tool shortcuts (0-5)
        if let tool = toolForKey(characters) {
            state.selectedTool = tool
            return true
        }

        // Delete selected annotation
        if event.keyCode == KeyCode.backspace || event.keyCode == KeyCode.delete {
            if state.selectedAnnotationId != nil {
                state.deleteSelectedAnnotation()
                return true
            }
        }

        // Cmd+Z for undo, Cmd+Shift+Z for redo
        if modifiers.contains(.command) && characters.lowercased() == "z" {
            if modifiers.contains(.shift) {
                state.redo()
            } else {
                state.undo()
            }
            return true
        }

        // Cmd+S for save
        if modifiers.contains(.command) && characters.lowercased() == "s" {
            onSave?()
            return true
        }

        // Escape to cancel
        if event.keyCode == KeyCode.escape {
            onCancel?()
            return true
        }

        // Return to save
        if event.keyCode == KeyCode.return {
            onSave?()
            return true
        }

        return false
    }

    private func toolForKey(_ key: String) -> AnnotationTool? {
        switch key {
        case "0": return .select
        case "1": return .arrow
        case "2": return .text
        case "3": return .freehand
        case "4": return .rectangle
        case "5": return .oval
        default: return nil
        }
    }
}

// MARK: - Key Codes

private enum KeyCode {
    static let escape: UInt16 = 53
    static let backspace: UInt16 = 51
    static let delete: UInt16 = 117
    static let `return`: UInt16 = 36
}
