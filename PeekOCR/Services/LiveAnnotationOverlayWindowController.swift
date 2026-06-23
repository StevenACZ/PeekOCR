import AppKit

@MainActor
final class LiveAnnotationOverlayWindowController: NSWindowController {
    private struct Overlay {
        let window: NSWindow
        let view: LiveAnnotationOverlayView
    }

    private var overlays: [CGDirectDisplayID: Overlay] = [:]
    private var activeDisplayID: CGDirectDisplayID?
    private var continuation: CheckedContinuation<(selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])?, Never>?

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func runSession(
        mode: LiveAnnotationOverlayView.OverlayMode = .annotate
    ) async -> (selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])? {
        let screens = DisplayEnumerator.activeScreens()
        guard !screens.isEmpty else { return nil }

        overlays = [:]
        activeDisplayID = nil

        for (displayID, screen) in screens {
            let overlay = makeOverlay(for: screen, displayID: displayID, mode: mode)
            overlays[displayID] = overlay
            overlay.window.alphaValue = 0
            // The app is usually inactive when the hotkey fires; orderFrontRegardless
            // is the only call that brings the window up without waiting for activation.
            overlay.window.orderFrontRegardless()
        }

        // Pick the overlay under the cursor. Annotate makes this key for keyboard
        // shortcuts; quick select stays non-activating and mouse-driven.
        let mouseLocation = NSEvent.mouseLocation
        let primaryOverlay =
            overlays.values.first { $0.window.frame.contains(mouseLocation) }
            ?? overlays.values.first
        self.window = primaryOverlay?.window

        if mode == .annotate, let primaryOverlay {
            NSApp.activate(ignoringOtherApps: true)
            primaryOverlay.window.makeKeyAndOrderFront(nil)
            primaryOverlay.window.makeFirstResponder(primaryOverlay.view)
        }
        NSCursor.crosshair.set()

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.15
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
        for overlay in overlays.values {
            overlay.window.animator().alphaValue = 1
        }
        NSAnimationContext.endGrouping()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Cancel an in-flight session programmatically (e.g. the clip hotkey
    /// fired again while the user was still selecting the region).
    func cancelSession() {
        finish(with: nil)
    }

    // MARK: - Private

    private func makeOverlay(
        for screen: NSScreen, displayID: CGDirectDisplayID, mode: LiveAnnotationOverlayView.OverlayMode
    ) -> Overlay {
        let window = makeWindow(for: mode, frame: screen.frame)
        // Force global-coordinate frame: passing `screen:` to the initializer
        // makes AppKit treat contentRect.origin as screen-relative and double it.
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = false

        let view = LiveAnnotationOverlayView(screen: screen, mode: mode)
        view.resetState()
        view.onCancel = { [weak self] in
            self?.finish(with: nil)
        }
        view.onComplete = { [weak self] selectionRect, completedScreen, annotations in
            self?.finish(with: (selectionRect, completedScreen, annotations))
        }
        view.onActivate = { [weak self] in
            self?.handleActivation(displayID: displayID)
        }

        window.contentView = view
        view.frame = window.contentView?.bounds ?? .zero
        view.autoresizingMask = [.width, .height]

        return Overlay(window: window, view: view)
    }

    private func makeWindow(for mode: LiveAnnotationOverlayView.OverlayMode, frame: CGRect) -> NSWindow {
        switch mode {
        case .annotate:
            return LiveAnnotationOverlayWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
        case .quickSelect:
            let panel = LiveAnnotationQuickSelectOverlayPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.hidesOnDeactivate = false
            return panel
        }
    }

    private func handleActivation(displayID: CGDirectDisplayID) {
        guard activeDisplayID == nil else { return }
        activeDisplayID = displayID
        for (otherID, overlay) in overlays where otherID != displayID {
            overlay.window.orderOut(nil)
        }
    }

    private func finish(with result: (CGRect, NSScreen, [LiveAnnotation])?) {
        for overlay in overlays.values {
            overlay.window.orderOut(nil)
        }
        overlays.removeAll()
        activeDisplayID = nil
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private final class LiveAnnotationOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class LiveAnnotationQuickSelectOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
