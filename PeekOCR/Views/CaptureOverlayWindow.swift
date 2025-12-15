//
//  CaptureOverlayWindow.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI

/// Full-screen transparent window for area selection
final class CaptureOverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    private weak var coordinator: CaptureCoordinator?
    private var overlayView: CaptureOverlayView?
    
    // MARK: - Initialization
    
    init(screen: NSScreen, coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
        
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        setup()
    }
    
    // MARK: - Setup
    
    private func setup() {
        // Window configuration for overlay
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // Create and set the overlay view
        let view = CaptureOverlayView(frame: frame, coordinator: coordinator)
        overlayView = view
        contentView = view
        
        // Make window key and front
        makeFirstResponder(view)
        
        // Order front first
        orderFrontRegardless()
        
        // Use a small delay to ensure window is fully ready for events
        // This prevents the "first click not registering" issue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.makeKey()
            self?.makeMain()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Overrides
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Cancel on Escape
        if event.keyCode == 53 { // Escape key
            coordinator?.cancelCapture()
        }
    }
}

// MARK: - Capture Overlay View

final class CaptureOverlayView: NSView {
    
    // MARK: - Properties
    
    private weak var coordinator: CaptureCoordinator?
    
    private var selectionStart: NSPoint?
    private var selectionEnd: NSPoint?
    private var isSelecting = false
    
    private let overlayColor = NSColor.black.withAlphaComponent(0.3)
    private let selectionBorderColor = NSColor.systemBlue
    private let selectionFillColor = NSColor.systemBlue.withAlphaComponent(0.1)
    
    // MARK: - Initialization
    
    init(frame: NSRect, coordinator: CaptureCoordinator?) {
        self.coordinator = coordinator
        super.init(frame: frame)
        
        // Setup for immediate mouse interaction
        wantsLayer = true
        
        // Setup tracking area for mouse moved events
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw semi-transparent overlay
        overlayColor.setFill()
        bounds.fill()
        
        // If selecting, draw the selection rectangle
        if isSelecting, let start = selectionStart, let end = selectionEnd {
            let selectionRect = rectFromPoints(start, end)
            
            // Clear the selection area (make it transparent)
            NSColor.clear.setFill()
            selectionRect.fill(using: .clear)
            
            // Draw selection border
            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 2
            selectionBorderColor.setStroke()
            borderPath.stroke()
            
            // Draw subtle fill
            selectionFillColor.setFill()
            selectionRect.fill()
            
            // Draw dimension label
            drawDimensionLabel(for: selectionRect)
        }
        
        // Draw instructions
        drawInstructions()
        
        // Draw crosshair cursor hint
        drawCrosshairHint()
    }
    
    private func drawDimensionLabel(for rect: NSRect) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let dimensionText = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        
        let string = NSAttributedString(string: " \(dimensionText) ", attributes: attributes)
        let size = string.size()
        
        // Position below the selection
        var labelPoint = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 8)
        
        // Keep label in bounds
        if labelPoint.y < 10 {
            labelPoint.y = rect.maxY + 8
        }
        
        string.draw(at: labelPoint)
    }
    
    private func drawInstructions() {
        let instructions = "Arrastra para seleccionar • ESC para cancelar"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let string = NSAttributedString(string: instructions, attributes: attributes)
        let size = string.size()
        
        // Draw centered at top
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 60)
        
        // Draw background pill
        let pillRect = NSRect(
            x: point.x - 16,
            y: point.y - 8,
            width: size.width + 32,
            height: size.height + 16
        )
        
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
        NSColor.black.withAlphaComponent(0.7).setFill()
        pillPath.fill()
        
        string.draw(at: point)
    }
    
    private func drawCrosshairHint() {
        // Don't draw if already selecting
        guard !isSelecting else { return }
        
        // Get current mouse location
        guard let window = window else { return }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let localPoint = convert(mouseLocation, from: nil)
        
        // Only draw if mouse is in bounds
        guard bounds.contains(localPoint) else { return }
        
        // Draw crosshair lines
        let lineColor = NSColor.white.withAlphaComponent(0.5)
        lineColor.setStroke()
        
        let path = NSBezierPath()
        path.lineWidth = 1
        
        // Vertical line
        path.move(to: NSPoint(x: localPoint.x, y: 0))
        path.line(to: NSPoint(x: localPoint.x, y: bounds.height))
        
        // Horizontal line
        path.move(to: NSPoint(x: 0, y: localPoint.y))
        path.line(to: NSPoint(x: bounds.width, y: localPoint.y))
        
        path.stroke()
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionStart = point
        selectionEnd = point
        isSelecting = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isSelecting else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectionEnd = point
        needsDisplay = true
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Redraw to update crosshair position
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isSelecting, let start = selectionStart, let end = selectionEnd else {
            return
        }
        
        isSelecting = false
        
        let selectionRect = rectFromPoints(start, end)
        
        // Only process if the selection is large enough
        if selectionRect.width > 10 && selectionRect.height > 10 {
            // Convert to screen coordinates
            if let screen = window?.screen {
                let screenRect = convertToScreenCoordinates(selectionRect, in: screen)
                coordinator?.processRegion(screenRect)
            }
        } else {
            // Selection too small, cancel
            coordinator?.cancelCapture()
        }
    }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    // MARK: - Helpers
    
    private func rectFromPoints(_ p1: NSPoint, _ p2: NSPoint) -> NSRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let width = abs(p2.x - p1.x)
        let height = abs(p2.y - p1.y)
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func convertToScreenCoordinates(_ rect: NSRect, in screen: NSScreen) -> CGRect {
        // NSView coordinates are flipped relative to CGImage/screen capture coordinates
        let screenFrame = screen.frame
        
        // Convert from view coordinates to screen coordinates
        let x = screenFrame.origin.x + rect.origin.x
        let y = screenFrame.origin.y + (screenFrame.height - rect.origin.y - rect.height)
        
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }
}
