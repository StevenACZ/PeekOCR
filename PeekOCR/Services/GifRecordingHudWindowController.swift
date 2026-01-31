//
//  GifRecordingHudWindowController.swift
//  PeekOCR
//
//  Presents a small, non-activating HUD window during GIF recording.
//

import AppKit

/// Window controller for the recording HUD (countdown + stop button).
@MainActor
final class GifRecordingHudWindowController: NSWindowController {
    private let hudView = GifRecordingHudView(frame: .zero)

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(on screen: NSScreen, selectionRectInScreen: CGRect, elapsedSeconds: Int, onStop: @escaping () -> Void) {
        hudView.elapsedSeconds = elapsedSeconds
        hudView.onStop = onStop

        let panel = createHudPanel()
        panel.contentView = hudView
        panel.layoutIfNeeded()

        let size = hudView.fittingSize
        let origin = hudOrigin(for: size, on: screen, avoiding: selectionRectInScreen)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)

        window = panel
        panel.orderFrontRegardless()
    }

    func updateElapsedSeconds(_ seconds: Int) {
        hudView.elapsedSeconds = seconds
    }

    func closeHud() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func createHudPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 240, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary,
        ]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        return panel
    }

    private func hudOrigin(for size: CGSize, on screen: NSScreen, avoiding selectionRectInScreen: CGRect) -> CGPoint {
        let inset: CGFloat = 16
        let frame = screen.visibleFrame
        let avoidanceRect = selectionRectInScreen.insetBy(dx: -12, dy: -12)

        let candidates: [CGPoint] = [
            CGPoint(x: frame.maxX - size.width - inset, y: frame.maxY - size.height - inset), // top-right
            CGPoint(x: frame.minX + inset, y: frame.maxY - size.height - inset), // top-left
            CGPoint(x: frame.maxX - size.width - inset, y: frame.minY + inset), // bottom-right
            CGPoint(x: frame.minX + inset, y: frame.minY + inset), // bottom-left
        ]

        for origin in candidates {
            let rect = CGRect(origin: origin, size: size)
            if !rect.intersects(avoidanceRect) {
                return origin
            }
        }

        // Fallback if the selection covers most of the screen.
        return CGPoint(x: frame.maxX - size.width - inset, y: frame.maxY - size.height - inset)
    }
}
