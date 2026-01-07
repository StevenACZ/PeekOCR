//
//  AnnotationWindowFactory.swift
//  PeekOCR
//
//  Creates and configures NSWindow for the annotation editor.
//

import AppKit

/// Factory for creating annotation editor windows
enum AnnotationWindowFactory {
    /// Create a configured window for the annotation editor
    /// - Parameters:
    ///   - size: The window size
    ///   - delegate: The window delegate
    /// - Returns: Configured NSWindow
    static func createWindow(size: CGSize, delegate: NSWindowDelegate?) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Editor de Anotaciones"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        window.backgroundColor = NSColor.controlBackgroundColor
        window.minSize = NSSize(width: 500, height: 400)

        return window
    }

    /// Calculate optimal window size for a given image
    /// - Parameter image: The source CGImage
    /// - Returns: Calculated window size
    static func calculateWindowSize(for image: CGImage) -> CGSize {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        // Get screen size for constraints
        guard let screen = NSScreen.main else {
            return CGSize(width: max(imageWidth, 600), height: max(imageHeight, 400))
        }

        let screenFrame = screen.visibleFrame
        let maxWidth = screenFrame.width * 0.7
        let maxHeight = screenFrame.height * 0.7
        let toolbarWidth: CGFloat = 200

        // Calculate scaled size maintaining aspect ratio
        var width = imageWidth + toolbarWidth
        var height = imageHeight

        // Scale down if too large
        if width > maxWidth {
            let scale = maxWidth / width
            width = maxWidth
            height *= scale
        }

        if height > maxHeight {
            let scale = maxHeight / height
            height = maxHeight
            width = (width - toolbarWidth) * scale + toolbarWidth
        }

        // Ensure minimum size
        width = max(width, 600)
        height = max(height, 400)

        return CGSize(width: width, height: height)
    }
}
