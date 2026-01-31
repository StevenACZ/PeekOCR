//
//  GifRecordingOverlayView.swift
//  PeekOCR
//
//  Full-screen overlay for selecting and recording a GIF region.
//

import AppKit

/// Overlay view that darkens the screen and highlights a selected recording region.
final class GifRecordingOverlayView: NSView {
    enum Mode {
        case selecting
        case recording
    }

    var mode: Mode = .selecting {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            updateCursor()
        }
    }

    var selectionRectInScreen: CGRect? {
        didSet { needsDisplay = true }
    }

    var onSelection: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStartInScreen: CGPoint?
    private var activeScreen: NSScreen?

    override var acceptsFirstResponder: Bool { true }

    func resetInteractionState() {
        dragStartInScreen = nil
        activeScreen = nil
        selectionRectInScreen = nil
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.invalidateCursorRects(for: self)
        updateCursor()
    }

    override func resetCursorRects() {
        discardCursorRects()
        let cursor: NSCursor = (mode == .selecting) ? .crosshair : .arrow
        addCursorRect(bounds, cursor: cursor)
    }

    override func keyDown(with event: NSEvent) {
        // Escape
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard mode == .selecting, let window else { return }

        let pointInWindow = event.locationInWindow
        let startInScreen = window.convertToScreen(NSRect(origin: pointInWindow, size: .zero)).origin
        guard let screen = Self.screen(containing: startInScreen) else { return }

        activeScreen = screen
        dragStartInScreen = clamp(startInScreen, to: screen.frame)
        selectionRectInScreen = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .selecting, let window, let start = dragStartInScreen, let screen = activeScreen else { return }

        let currentInScreen = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        let clampedCurrent = clamp(currentInScreen, to: screen.frame)

        selectionRectInScreen = normalizedRect(from: start, to: clampedCurrent)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStartInScreen = nil
            activeScreen = nil
        }

        guard mode == .selecting, let screen = activeScreen else { return }
        guard let rect = selectionRectInScreen, rect.width >= 20, rect.height >= 20 else {
            selectionRectInScreen = nil
            needsDisplay = true
            return
        }

        onSelection?(rect, screen)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let window else { return }

        NSColor.clear.setFill()
        dirtyRect.fill()

        let overlayAlpha: CGFloat = mode == .recording ? 0.55 : 0.45
        let overlayColor = NSColor.black.withAlphaComponent(overlayAlpha)

        if let rectInScreen = selectionRectInScreen {
            let rectInWindow = window.convertFromScreen(rectInScreen)
            let rectInView = convert(rectInWindow, from: nil)
            let holeRect = (mode == .recording) ? rectInView.insetBy(dx: -2, dy: -2) : rectInView

            let path = NSBezierPath(rect: bounds)
            path.appendRect(holeRect)
            path.windingRule = .evenOdd
            overlayColor.setFill()
            path.fill()

            if mode == .selecting {
                NSColor.systemBlue.setStroke()
                let border = NSBezierPath(roundedRect: rectInView.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
                border.lineWidth = 2
                border.stroke()
            }

            if mode == .recording {
                drawRecordingBorder(around: rectInView)
            }

            if mode == .selecting {
                drawSelectionHud(in: rectInView)
            }
        } else {
            // Do not dim the screen until the user starts dragging a selection.
            if mode == .selecting, dragStartInScreen == nil {
                drawHintPill(text: "Arrastra para seleccionar • Esc para cancelar")
            } else {
                overlayColor.setFill()
                bounds.fill()
            }
        }
    }

    // MARK: - Drawing

    private func drawHintPill(text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)

        let paddingX: CGFloat = 12
        let paddingY: CGFloat = 8
        let pillSize = CGSize(width: textSize.width + paddingX * 2, height: textSize.height + paddingY * 2)
        let pillRect = CGRect(
            x: bounds.midX - pillSize.width / 2,
            y: bounds.maxY - pillSize.height - 24,
            width: pillSize.width,
            height: pillSize.height
        )

        NSColor.black.withAlphaComponent(0.55).setFill()
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
        path.fill()

        let textOrigin = CGPoint(x: pillRect.minX + paddingX, y: pillRect.minY + paddingY)
        (text as NSString).draw(at: textOrigin, withAttributes: attributes)
    }

    private func drawSelectionHud(in selectionRect: CGRect) {
        let text = "Suelta para empezar a grabar"
        drawPill(text: text, in: selectionRect, color: NSColor.black.withAlphaComponent(0.55))
    }

    private func drawRecordingBorder(around selectionRect: CGRect) {
        let lineWidth: CGFloat = 2
        let outsideInset: CGFloat = lineWidth / 2 + 3

        let borderRect = selectionRect.insetBy(dx: -outsideInset, dy: -outsideInset)
        let path = NSBezierPath(roundedRect: borderRect, xRadius: 8, yRadius: 8)
        path.lineWidth = lineWidth

        NSGraphicsContext.saveGraphicsState()
        // Ensure the border (and any glow) never draws inside the captured rectangle.
        let clip = NSBezierPath(rect: bounds)
        clip.appendRect(selectionRect)
        clip.windingRule = .evenOdd
        clip.addClip()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.systemBlue.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = .zero
        shadow.set()

        NSColor.systemBlue.withAlphaComponent(0.95).setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawPill(text: String, in selectionRect: CGRect, color: NSColor) {
        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 6

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let pillSize = CGSize(width: textSize.width + paddingX * 2, height: textSize.height + paddingY * 2)

        let origin = CGPoint(
            x: selectionRect.minX + 12,
            y: selectionRect.maxY - pillSize.height - 12
        )
        let pillRect = CGRect(origin: origin, size: pillSize)

        color.setFill()
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillSize.height / 2, yRadius: pillSize.height / 2)
        path.fill()

        let textOrigin = CGPoint(x: pillRect.minX + paddingX, y: pillRect.minY + paddingY)
        (text as NSString).draw(at: textOrigin, withAttributes: attributes)
    }

    private func updateCursor() {
        if mode == .selecting {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Geometry

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}
