//
//  GifClipKeyboardHandler.swift
//  PeekOCR
//
//  Handles keyboard shortcuts for the GIF clip editor (play/pause, frame stepping, cancel).
//

import AppKit

/// Keyboard shortcuts handler for the GIF clip editor window.
final class GifClipKeyboardHandler {
    private var keyMonitor: Any?

    var onCancel: (() -> Void)?
    var onTogglePlay: (() -> Void)?
    var onStepFrame: ((Int) -> Void)?

    func setup() {
        teardown()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handle(event) { return nil }
            return event
        }
    }

    func teardown() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        // Escape
        if event.keyCode == KeyCode.escape {
            onCancel?()
            return true
        }

        // Space toggles play/pause
        if event.keyCode == KeyCode.space {
            onTogglePlay?()
            return true
        }

        // Left/right arrows step frames
        if event.keyCode == KeyCode.leftArrow {
            onStepFrame?(-1)
            return true
        }
        if event.keyCode == KeyCode.rightArrow {
            onStepFrame?(1)
            return true
        }

        return false
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}

