//
//  RecordingFrameWindowController.swift
//  PeekOCR
//
//  Click-through window that outlines the region being recorded. The capture
//  filter excludes this app, and as a second line of defense the stroke is
//  drawn entirely OUTSIDE the captured rect, so it can never overlap the
//  recorded pixels.
//

import AppKit

@MainActor
final class RecordingFrameWindowController {
    private var window: NSWindow?
    private var frameView: RecordingFrameView?

    func show(around rectInScreen: CGRect) {
        let padding = RecordingFrameView.outlinePadding
        let frame = rectInScreen.insetBy(dx: -padding, dy: -padding)

        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = true

        let view = RecordingFrameView(frame: CGRect(origin: .zero, size: frame.size))
        window.contentView = view
        window.orderFrontRegardless()
        self.window = window
        self.frameView = view
    }

    func setPaused(_ paused: Bool) {
        frameView?.isPaused = paused
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        frameView = nil
    }
}

/// Draws the recording outline in the ring around the captured area (the
/// area itself starts `outlinePadding` points inside these bounds): a soft
/// dark halo for light backgrounds plus a crisp accent stroke. Orange while
/// the recording is paused.
private final class RecordingFrameView: NSView {
    static let outlinePadding: CGFloat = 8

    var isPaused: Bool = false {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Stroke centerlines sit at 4.5pt from the window edge; with widths
        // of 5 and 2 they span 2–7pt, fully outside the captured rect at 8pt.
        let outline = bounds.insetBy(dx: 4.5, dy: 4.5)

        let halo = NSBezierPath(roundedRect: outline, xRadius: 7, yRadius: 7)
        halo.lineWidth = 5
        NSColor.black.withAlphaComponent(0.3).setStroke()
        halo.stroke()

        let stroke = NSBezierPath(roundedRect: outline, xRadius: 7, yRadius: 7)
        stroke.lineWidth = 2
        (isPaused ? NSColor.systemOrange : NSColor.controlAccentColor).setStroke()
        stroke.stroke()
    }
}
