import AppKit

@MainActor
final class LiveAnnotationOverlayWindowController: NSWindowController {
    private let overlayView = LiveAnnotationOverlayView()
    private var continuation: CheckedContinuation<(selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])?, Never>?

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func runSession() async -> (selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])? {
        let window = createOverlayWindow()
        self.window = window

        overlayView.resetState()
        overlayView.onCancel = { [weak self] in
            self?.finish(with: nil)
        }
        overlayView.onComplete = { [weak self] selectionRect, screen, annotations in
            self?.finish(with: (selectionRect, screen, annotations))
        }

        window.contentView = overlayView
        overlayView.frame = window.contentView?.bounds ?? .zero
        overlayView.autoresizingMask = [.width, .height]

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(overlayView)
        NSApp.activate(ignoringOtherApps: true)

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func finish(with result: (CGRect, NSScreen, [LiveAnnotation])?) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func createOverlayWindow() -> NSWindow {
        let frame = NSScreen.screens.reduce(into: CGRect.null) { partialResult, screen in
            partialResult = partialResult.union(screen.frame)
        }

        let window = LiveAnnotationOverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = false
        return window
    }
}

private final class LiveAnnotationOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
