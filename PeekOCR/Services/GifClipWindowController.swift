//
//  GifClipWindowController.swift
//  PeekOCR
//
//  Manages the GIF clip editor window lifecycle and async continuation.
//

import AppKit
import SwiftUI

/// Window controller for the GIF clip editor
final class GifClipWindowController: NSWindowController {
    static let shared = GifClipWindowController()

    // MARK: - Properties

    private var continuation: CheckedContinuation<ClipExportResult?, Never>?
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

    /// Show the GIF clip editor for a recorded video.
    @MainActor
    func showEditor(with videoURL: URL, saveDirectory: URL) async -> ClipExportResult? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            presentEditor(with: videoURL, saveDirectory: saveDirectory)
        }
    }

    /// Close the editor window.
    @MainActor
    func closeEditor() {
        window?.close()
        cleanup()
    }

    // MARK: - Private Methods

    @MainActor
    private func presentEditor(with videoURL: URL, saveDirectory: URL) {
        if let existingWindow = window {
            existingWindow.close()
        }
        cleanup()

        currentEditorId = UUID()

        let size = GifClipWindowFactory.calculateWindowSize()
        let window = GifClipWindowFactory.createWindow(size: size, delegate: self)

        let editorView = GifClipEditorView(
            videoURL: videoURL,
            saveDirectory: saveDirectory,
            onExport: { [weak self] result in
                self?.handleExport(result)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )

        let hostingController = NSHostingController(rootView: AnyView(editorView.id(currentEditorId)))
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        window.contentViewController = hostingController
        self.hostingController = hostingController
        self.window = window

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func handleExport(_ result: ClipExportResult) {
        continuation?.resume(returning: result)
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

extension GifClipWindowController: NSWindowDelegate {
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
