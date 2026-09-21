import AppKit
import XCTest

@testable import PeekOCR

@MainActor
final class AnnotationInteractionTests: XCTestCase {
    func testConsecutiveDrawingGesturesEachCreateAnAnnotation() throws {
        for tool in [LiveAnnotationTool.arrow, .pen, .highlight] {
            let (window, view) = try makeOverlay()
            defer { window.close() }
            view.selectedTool = tool
            try drag(view, window: window, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 220, y: 200))
            try drag(view, window: window, from: CGPoint(x: 350, y: 100), to: CGPoint(x: 470, y: 200))
            XCTAssertEqual(view.annotations.count, 2, "Each \(tool) gesture should draw immediately")
        }
    }

    func testTextStartsImmediatelyAfterADrawing() throws {
        let (window, view) = try makeOverlay()
        defer { window.close() }
        view.selectedTool = .arrow
        try drag(view, window: window, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 220, y: 200))
        view.selectedTool = .text
        view.mouseDown(with: try event(.leftMouseDown, window: window, point: CGPoint(x: 350, y: 250)))
        XCTAssertTrue(view.isEditingText)
        view.dismissTextEditor(commit: false)
        XCTAssertEqual(view.annotations.count, 1)
    }

    func testSelectToolStillDeselectsWithoutMovingTheRegion() throws {
        let (window, view) = try makeOverlay()
        defer { window.close() }
        view.selectedTool = .arrow
        try drag(view, window: window, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 220, y: 200))
        let originalRect = view.selectionRectInScreen
        view.selectedTool = .select
        view.mouseDown(with: try event(.leftMouseDown, window: window, point: CGPoint(x: 160, y: 150)))
        view.mouseUp(with: try event(.leftMouseUp, window: window, point: CGPoint(x: 160, y: 150)))
        try drag(view, window: window, from: CGPoint(x: 350, y: 100), to: CGPoint(x: 470, y: 200))
        XCTAssertEqual(view.annotations.count, 1)
        XCTAssertEqual(view.selectionRectInScreen, originalRect)
        XCTAssertNil(view.selectedAnnotationID)
    }

    private func makeOverlay() throws -> (NSWindow, LiveAnnotationOverlayView) {
        let screen = try XCTUnwrap(NSScreen.main)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = LiveAnnotationOverlayView(screen: screen, mode: .annotate)
        window.contentView = view
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        view.selectionRectInScreen = window.convertToScreen(CGRect(x: 50, y: 50, width: 600, height: 400))
        return (window, view)
    }

    private func drag(_ view: LiveAnnotationOverlayView, window: NSWindow, from start: CGPoint, to end: CGPoint) throws {
        view.mouseDown(with: try event(.leftMouseDown, window: window, point: start))
        view.mouseDragged(with: try event(.leftMouseDragged, window: window, point: end))
        view.mouseUp(with: try event(.leftMouseUp, window: window, point: end))
    }

    private func event(_ type: NSEvent.EventType, window: NSWindow, point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
}
