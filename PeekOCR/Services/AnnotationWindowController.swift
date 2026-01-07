//
//  AnnotationWindowController.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import AppKit
import SwiftUI

/// Window controller for the annotation editor
final class AnnotationWindowController: NSWindowController {
    static let shared = AnnotationWindowController()

    // MARK: - Properties

    private var continuation: CheckedContinuation<CGImage?, Never>?
    private var hostingController: NSHostingController<AnyView>?
    private var currentEditorId = UUID()

    // MARK: - Initialization

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// Show the annotation editor with the given image
    /// - Parameter image: The base image to annotate
    /// - Returns: The annotated image, or nil if cancelled
    @MainActor
    func showEditor(with image: CGImage) async -> CGImage? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presentEditor(with: image)
        }
    }

    /// Close the annotation editor
    @MainActor
    func closeEditor() {
        window?.close()
        cleanup()
    }

    // MARK: - Private Methods

    @MainActor
    private func presentEditor(with image: CGImage) {
        // Cerrar ventana anterior si existe
        if let existingWindow = window {
            existingWindow.close()
        }
        cleanup()

        // Nuevo ID para forzar recreación de SwiftUI
        currentEditorId = UUID()

        // Calculate window size based on image
        let windowSize = calculateWindowSize(for: image)

        // Create the window
        let window = createWindow(size: windowSize)

        // Create fresh state for each session (outside of SwiftUI)
        let annotationState = AnnotationState()

        // Create the content view
        let editorView = AnnotationEditorView(
            baseImage: image,
            imageId: currentEditorId,
            state: annotationState,
            onSave: { [weak self] annotatedImage in
                self?.handleSave(annotatedImage)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )

        // Create hosting controller with unique ID to force SwiftUI recreation
        let hostingController = NSHostingController(rootView: AnyView(editorView.id(currentEditorId)))
        hostingController.view.frame = CGRect(origin: .zero, size: windowSize)

        window.contentViewController = hostingController
        self.hostingController = hostingController
        self.window = window

        // Show the window
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Make the app active to bring window to front
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow(size: CGSize) -> NSWindow {
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
        window.delegate = self
        window.backgroundColor = NSColor.controlBackgroundColor

        // Set minimum size
        window.minSize = NSSize(width: 500, height: 400)

        return window
    }

    private func calculateWindowSize(for image: CGImage) -> CGSize {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        // Get screen size for constraints
        guard let screen = NSScreen.main else {
            return CGSize(width: max(imageWidth, 600), height: max(imageHeight, 400))
        }

        let screenFrame = screen.visibleFrame
        let maxWidth = screenFrame.width * 0.7
        let maxHeight = screenFrame.height * 0.7

        // Add toolbar width
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

    @MainActor
    private func handleSave(_ image: CGImage) {
        continuation?.resume(returning: image)
        continuation = nil
        closeEditor()
    }

    @MainActor
    private func handleCancel() {
        continuation?.resume(returning: nil)
        continuation = nil
        closeEditor()
    }

    private func cleanup() {
        // Force destroy the view hierarchy to prevent zombie Canvas
        if let hc = hostingController {
            hc.view.removeFromSuperview()
            hc.rootView = AnyView(EmptyView())
        }
        if let w = window {
            w.contentViewController = nil
            w.contentView = nil
        }
        hostingController = nil
        window = nil
    }
}

// MARK: - NSWindowDelegate

extension AnnotationWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // If window is closed without save/cancel, treat as cancel
        if continuation != nil {
            Task { @MainActor in
                handleCancel()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure window stays on top when it becomes key
        window?.level = .floating
    }
}
