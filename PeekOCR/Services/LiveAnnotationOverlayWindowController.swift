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

    func runSession() async -> (selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])? {
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
            self.continuation = continuation
        }
    }

    // MARK: - Private

    private func makeOverlay(for screen: NSScreen, displayID: CGDirectDisplayID) -> Overlay {
        let window = LiveAnnotationOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Force global-coordinate frame: passing `screen:` to the initializer
        // makes AppKit treat contentRect.origin as screen-relative and double it.
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = false

        let view = LiveAnnotationOverlayView(screen: screen)
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
