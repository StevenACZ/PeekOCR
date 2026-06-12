//
//  CaptureFlashEffect.swift
//  PeekOCR
//
//  Brief white flash over the captured region, mimicking native screenshot feedback.
//

import AppKit

@MainActor
enum CaptureFlashEffect {
    /// Shows a short flash over `rectInScreen` (AppKit global coordinates).
    /// Call after the pixels were captured so the flash never lands in the image.
    static func flash(rectInScreen: CGRect) {
        guard rectInScreen.width > 0, rectInScreen.height > 0 else { return }

        let window = NSWindow(
            contentRect: rectInScreen,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let view = NSView(frame: NSRect(origin: .zero, size: rectInScreen.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        view.layer?.cornerRadius = 6
        window.contentView = view

        window.alphaValue = 0.8
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 0
            },
            completionHandler: {
                window.orderOut(nil)
            }
        )
    }
}
