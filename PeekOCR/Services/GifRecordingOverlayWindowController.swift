//
//  GifRecordingOverlayWindowController.swift
//  PeekOCR
//
//  Manages one overlay window per active display for selecting and recording a GIF region.
//

import AppKit

@MainActor
final class GifRecordingOverlayWindowController: NSWindowController {
    private struct Overlay {
        let window: NSWindow
        let view: GifRecordingOverlayView
    }

    private var overlays: [CGDirectDisplayID: Overlay] = [:]
    private var activeDisplayID: CGDirectDisplayID?
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
        let screens = DisplayEnumerator.activeScreens()
        guard !screens.isEmpty else { return nil }

        overlays = [:]
        activeDisplayID = nil

        for (displayID, screen) in screens {
            let overlay = makeOverlay(for: screen, displayID: displayID)
            overlays[displayID] = overlay
            overlay.window.makeKeyAndOrderFront(nil)
            overlay.window.makeFirstResponder(overlay.view)
        }

        self.window = overlays.values.first?.window
        NSApp.activate(ignoringOtherApps: true)

        return await withCheckedContinuation { continuation in
            selectionContinuation = continuation
        }.map { rect, screen in (rect: rect, screen: screen) }
    }

    func beginRecording(
        selectionRectInScreen: CGRect,
        screen: NSScreen,
        maxDurationSeconds: Int,
        onStop: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard let activeID = activeDisplayID, let activeOverlay = overlays[activeID] else { return }
        activeOverlay.view.mode = .recording
        activeOverlay.view.selectionRectInScreen = selectionRectInScreen
        activeOverlay.view.onCancel = onCancel
        activeOverlay.window.ignoresMouseEvents = true

        let hud = GifRecordingHudWindowController()
        hud.show(
            on: screen,
            selectionRectInScreen: selectionRectInScreen,
            maxDurationSeconds: maxDurationSeconds,
            onStop: onStop
        )
        hudController = hud
    }

    func updateRecordingHud(elapsedSeconds: Int, maxDurationSeconds: Int) {
        hudController?.update(elapsedSeconds: elapsedSeconds, maxDurationSeconds: maxDurationSeconds)
    }

    func closeOverlay() {
        hudController?.closeHud()
        hudController = nil
        for overlay in overlays.values {
            overlay.window.orderOut(nil)
        }
        overlays.removeAll()
        activeDisplayID = nil
        window = nil
    }

    func cancelSelection() {
        finishSelection(nil)
    }

    // MARK: - Private

    private func makeOverlay(for screen: NSScreen, displayID: CGDirectDisplayID) -> Overlay {
        let window = KeyableOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = false

        let view = GifRecordingOverlayView(screen: screen)
        view.mode = .selecting
        view.resetInteractionState()
        view.onCancel = { [weak self] in
            self?.finishSelection(nil)
        }
        view.onSelection = { [weak self] rect, completedScreen in
            self?.finishSelection((rect, completedScreen))
        }
        view.onActivate = { [weak self] in
            self?.handleActivation(displayID: displayID)
        }

        window.contentView = view
        view.frame = window.contentView?.bounds ?? .zero
        view.autoresizingMask = [.width, .height]
        window.makeFirstResponder(view)

        return Overlay(window: window, view: view)
    }

    private func handleActivation(displayID: CGDirectDisplayID) {
        guard activeDisplayID == nil else { return }
        activeDisplayID = displayID
        for (otherID, overlay) in overlays where otherID != displayID {
            overlay.window.orderOut(nil)
        }
    }

    private func finishSelection(_ selection: (CGRect, NSScreen)?) {
        selectionContinuation?.resume(returning: selection)
        selectionContinuation = nil

        if selection == nil {
            closeOverlay()
        }
    }
}

private final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
