//
//  RecordingHudWindowController.swift
//  PeekOCR
//
//  Presents a small, non-activating HUD window during clip recording.
//

import AppKit

/// Window controller for the recording HUD (timer + controls).
@MainActor
final class RecordingHudWindowController: NSWindowController {
    private let hudView = RecordingHudView(frame: .zero)

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        on screen: NSScreen,
        selectionRectInScreen: CGRect,
        maxDurationSeconds: Int,
        quality: String,
        onStop: @escaping () -> Void,
        onTogglePause: @escaping () -> Void
    ) {
        hudView.maxDurationSeconds = max(0, maxDurationSeconds)
        hudView.elapsedSeconds = 0
        hudView.qualityText = quality
        hudView.onStop = onStop
        hudView.onTogglePause = onTogglePause

        let panel = createHudPanel()
        panel.contentView = hudView
        panel.layoutIfNeeded()

        let size = hudView.fittingSize
        let origin = hudOrigin(for: size, on: screen, avoiding: selectionRectInScreen)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)

        window = panel
        panel.orderFrontRegardless()
    }

    func update(elapsedSeconds: Int, maxDurationSeconds: Int) {
        hudView.maxDurationSeconds = max(0, maxDurationSeconds)
        hudView.elapsedSeconds = max(0, elapsedSeconds)
    }

    func setPaused(_ paused: Bool) {
        hudView.isPaused = paused
    }

    func closeHud() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func createHudPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary,
        ]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        return panel
    }

    /// Keeps the HUD attached to the region: centered below it, else above
    /// it, else floating inside its bottom edge. The recording excludes this
    /// app's windows, so the inside position never shows up in the clip.
    private func hudOrigin(for size: CGSize, on screen: NSScreen, avoiding selectionRectInScreen: CGRect) -> CGPoint {
        let gap: CGFloat = 14
        let safeFrame = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let x = min(max(selectionRectInScreen.midX - size.width / 2, safeFrame.minX), safeFrame.maxX - size.width)

        let below = selectionRectInScreen.minY - gap - size.height
        if below >= safeFrame.minY {
            return CGPoint(x: x, y: below)
        }

        let above = selectionRectInScreen.maxY + gap
        if above + size.height <= safeFrame.maxY {
            return CGPoint(x: x, y: above)
        }

        return CGPoint(x: x, y: max(selectionRectInScreen.minY, safeFrame.minY) + 16)
    }
}
