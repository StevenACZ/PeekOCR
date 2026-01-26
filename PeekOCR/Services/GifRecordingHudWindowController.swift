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

    func show(on screen: NSScreen, remainingSeconds: Int, onStop: @escaping () -> Void) {
        hudView.remainingSeconds = remainingSeconds
        hudView.onStop = onStop

        let panel = createHudPanel()
        panel.contentView = hudView
        panel.layoutIfNeeded()

        let size = hudView.fittingSize
        let origin = hudOrigin(for: size, on: screen)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)

        window = panel
        panel.orderFrontRegardless()
    }

    func updateRemainingSeconds(_ seconds: Int) {
        hudView.remainingSeconds = seconds
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

    private func hudOrigin(for size: CGSize, on screen: NSScreen) -> CGPoint {
        let inset: CGFloat = 16
        let frame = screen.visibleFrame
        return CGPoint(
            x: frame.maxX - size.width - inset,
            y: frame.maxY - size.height - inset
        )
    }
}

