//
//  GifRecordingOverlayWindowController.swift
//  PeekOCR
//
//  Manages the full-screen overlay used for selecting and recording a GIF region.
//

import AppKit

/// Window controller for the full-screen GIF recording overlay.
@MainActor
final class GifRecordingOverlayWindowController: NSWindowController {
    private let overlayView = GifRecordingOverlayView()
    private var selectionContinuation: CheckedContinuation<(CGRect, NSScreen)?, Never>?
    private var hudController: GifRecordingHudWindowController?

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func runSelection() async -> (rect: CGRect, screen: NSScreen)? {
        let window = createOverlayWindow()
        self.window = window

        overlayView.mode = .selecting
        overlayView.resetInteractionState()

        overlayView.onCancel = { [weak self] in
            self?.finishSelection(nil)
        }
        overlayView.onSelection = { [weak self] rect, screen in
            self?.finishSelection((rect, screen))
        }

        window.contentView = overlayView
        overlayView.frame = window.contentView?.bounds ?? .zero
        overlayView.autoresizingMask = [.width, .height]

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(overlayView)
        NSApp.activate(ignoringOtherApps: true)

        return await withCheckedContinuation { continuation in
            selectionContinuation = continuation
        }.map { rect, screen in
            (rect: rect, screen: screen)
        }
    }

    func beginRecording(
        selectionRectInScreen: CGRect,
        screen: NSScreen,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard let window else { return }
        overlayView.mode = .recording
        overlayView.selectionRectInScreen = selectionRectInScreen
        overlayView.onCancel = onCancel
        window.ignoresMouseEvents = true

        let hud = GifRecordingHudWindowController()
        hud.show(on: screen, selectionRectInScreen: selectionRectInScreen, elapsedSeconds: 0, onStop: onStop)
        hudController = hud
    }

    func updateElapsedSeconds(_ seconds: Int) {
        hudController?.updateElapsedSeconds(seconds)
    }

    func closeOverlay() {
        hudController?.closeHud()
        hudController = nil
        window?.orderOut(nil)
        window = nil
    }

    func cancelSelection() {
        finishSelection(nil)
    }

    // MARK: - Private

    private func finishSelection(_ selection: (CGRect, NSScreen)?) {
        selectionContinuation?.resume(returning: selection)
        selectionContinuation = nil

        if selection == nil {
            closeOverlay()
        }
    }

    private func createOverlayWindow() -> NSWindow {
        let frame = unionFrameForAllScreens()
        let window = KeyableOverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary,
        ]
        window.ignoresMouseEvents = false
        window.makeFirstResponder(overlayView)

        return window
    }

    private func unionFrameForAllScreens() -> CGRect {
        NSScreen.screens.reduce(into: CGRect.null) { result, screen in
            result = result.union(screen.frame)
        }
    }
}

private final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
