//
//  AnnotationWindowController.swift
//  PeekOCR
//
//  Manages the annotation editor window lifecycle and async continuation.
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
        // Close existing window if any
        if let existingWindow = window {
            existingWindow.close()
        }
        cleanup()

        // New ID to force SwiftUI recreation
        currentEditorId = UUID()

        // Create window using factory
        let windowSize = AnnotationWindowFactory.calculateWindowSize(for: image)
        let window = AnnotationWindowFactory.createWindow(size: windowSize, delegate: self)

        // Create fresh state and editor view
        let annotationState = AnnotationState()
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

        // Create hosting controller with unique ID
        let hostingController = NSHostingController(rootView: AnyView(editorView.id(currentEditorId)))
        hostingController.view.frame = CGRect(origin: .zero, size: windowSize)

        window.contentViewController = hostingController
        self.hostingController = hostingController
        self.window = window

        // Show and activate
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        if continuation != nil {
            Task { @MainActor in
                handleCancel()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        window?.level = .floating
    }
}
