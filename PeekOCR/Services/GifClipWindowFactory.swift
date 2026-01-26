//
//  GifClipWindowFactory.swift
//  PeekOCR
//
//  Creates and configures NSWindow for the GIF clip editor.
//

import AppKit

/// Factory for creating GIF clip editor windows
enum GifClipWindowFactory {
    static func createWindow(size: CGSize, delegate: NSWindowDelegate?) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "PeekOCR Editor"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        window.backgroundColor = NSColor.controlBackgroundColor
        window.minSize = NSSize(width: 960, height: 640)

        return window
    }

    static func calculateWindowSize() -> CGSize {
        let fallback = CGSize(width: 1200, height: 720)
        guard let screen = NSScreen.main else { return fallback }

        let frame = screen.visibleFrame
        let maxWidth = frame.width * 0.8
        let maxHeight = frame.height * 0.8

        return CGSize(
            width: min(fallback.width, maxWidth),
            height: min(fallback.height, maxHeight)
        )
    }
}
