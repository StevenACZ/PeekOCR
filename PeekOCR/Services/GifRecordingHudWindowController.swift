//
//  GifRecordingHudWindowController.swift
//  PeekOCR
//
//  Presents a small, non-activating HUD window during GIF recording.
//

import AppKit

/// Window controller for the recording HUD (timer + controls).
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

    func show(
        on screen: NSScreen,
        selectionRectInScreen: CGRect,
        maxDurationSeconds: Int,
        onStop: @escaping () -> Void
    ) {
        hudView.maxDurationSeconds = max(0, maxDurationSeconds)
        hudView.elapsedSeconds = 0
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

    func update(elapsedSeconds: Int, maxDurationSeconds: Int) {
        hudView.maxDurationSeconds = max(0, maxDurationSeconds)
        hudView.elapsedSeconds = max(0, elapsedSeconds)
    }

    func closeHud() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func createHudPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 68),
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
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        return panel
    }

    private func hudOrigin(for size: CGSize, on screen: NSScreen, avoiding selectionRectInScreen: CGRect) -> CGPoint {
        let inset: CGFloat = 16
        let gap: CGFloat = 12
        let safeFrame = screen.visibleFrame.insetBy(dx: inset, dy: inset)
        let avoidanceRect = selectionRectInScreen.insetBy(dx: -12, dy: -12)

        func clampToSafeFrame(_ origin: CGPoint) -> CGPoint {
            let x = min(max(safeFrame.minX, origin.x), safeFrame.maxX - size.width)
            let y = min(max(safeFrame.minY, origin.y), safeFrame.maxY - size.height)
            return CGPoint(x: x, y: y)
        }

        func isValid(_ origin: CGPoint) -> Bool {
            let rect = CGRect(origin: origin, size: size)
            return safeFrame.contains(rect) && !rect.intersects(avoidanceRect)
        }

        let centeredAbove = clampToSafeFrame(CGPoint(
            x: selectionRectInScreen.midX - size.width / 2,
            y: selectionRectInScreen.maxY + gap
        ))
        if isValid(centeredAbove) {
            return centeredAbove
        }

        let centeredBelow = clampToSafeFrame(CGPoint(
            x: selectionRectInScreen.midX - size.width / 2,
            y: selectionRectInScreen.minY - gap - size.height
        ))
        if isValid(centeredBelow) {
            return centeredBelow
        }

        let candidates: [CGPoint] = [
            clampToSafeFrame(CGPoint(x: selectionRectInScreen.minX, y: selectionRectInScreen.maxY + gap)),
            clampToSafeFrame(CGPoint(x: selectionRectInScreen.maxX - size.width, y: selectionRectInScreen.maxY + gap)),
            clampToSafeFrame(CGPoint(x: selectionRectInScreen.minX, y: selectionRectInScreen.minY - gap - size.height)),
            clampToSafeFrame(CGPoint(x: selectionRectInScreen.maxX - size.width, y: selectionRectInScreen.minY - gap - size.height)),
            clampToSafeFrame(CGPoint(x: safeFrame.maxX - size.width, y: safeFrame.maxY - size.height)), // top-right
            clampToSafeFrame(CGPoint(x: safeFrame.minX, y: safeFrame.maxY - size.height)), // top-left
            clampToSafeFrame(CGPoint(x: safeFrame.maxX - size.width, y: safeFrame.minY)), // bottom-right
            clampToSafeFrame(CGPoint(x: safeFrame.minX, y: safeFrame.minY)), // bottom-left
        ]

        for origin in candidates where isValid(origin) {
            return origin
        }

        // Fallback if the selection covers most of the screen.
        return clampToSafeFrame(CGPoint(x: safeFrame.maxX - size.width, y: safeFrame.maxY - size.height))
    }
}
