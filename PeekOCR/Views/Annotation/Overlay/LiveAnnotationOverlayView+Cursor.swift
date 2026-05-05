// Live annotation overlay cursor state resolution.

import AppKit

extension LiveAnnotationOverlayView {
    func currentCursor() -> NSCursor {
        if let pointInScreen = currentMouseLocationInScreen() {
            return cursor(for: pointInScreen)
        }

        if selectionRectInScreen == nil {
            return .crosshair
        }

        return selectedTool == .text ? .iBeam : .openHand
    }

    func cursor(for pointInScreen: CGPoint) -> NSCursor {
        switch interaction {
        case .movingSelection, .movingAnnotation:
            return .closedHand
        case .resizingSelection, .resizingAnnotation:
            return .closedHand
        case .creatingSelection, .drawingAnnotation:
            return .crosshair
        case .none:
            break
        }

        if isPointInToolbar(pointInScreen) {
            return .pointingHand
        }

        if let selectedAnnotationID,
            let annotation = annotations.first(where: { $0.id == selectedAnnotationID }),
            hitTestAnnotationResizeHandle(for: annotation, at: pointInScreen) != nil
        {
            return .openHand
        }

        if let selectionRectInScreen,
            hitTestHandle(at: pointInScreen, selectionRectInScreen: selectionRectInScreen) != nil
        {
            return .openHand
        }

        if hitTestAnnotation(at: pointInScreen) != nil {
            return .openHand
        }

        guard let selectionRectInScreen else {
            return .crosshair
        }

        if selectionRectInScreen.contains(pointInScreen) {
            switch selectedTool {
            case .text:
                return .iBeam
            case .select:
                return .openHand
            case .arrow, .highlight:
                return .crosshair
            }
        }

        return .crosshair
    }

    func refreshCursorAppearance() {
        window?.invalidateCursorRects(for: self)
        updateCursor()
    }

    func updateCursor() {
        currentCursor().set()
    }

    func updateCursor(for event: NSEvent) {
        guard let window else {
            updateCursor()
            return
        }

        let pointInScreen = screenPoint(from: event.locationInWindow, window: window)
        cursor(for: pointInScreen).set()
    }

    func currentMouseLocationInScreen() -> CGPoint? {
        guard let window else { return nil }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        return screenPoint(from: mouseInWindow, window: window)
    }

    func isPointInToolbar(_ pointInScreen: CGPoint) -> Bool {
        guard let selectionRectInScreen else { return false }
        let selectionRect = convert(window?.convertFromScreen(selectionRectInScreen) ?? .zero, from: nil)
        let pointInView = viewPoint(from: pointInScreen)
        return toolbarButtonFrames(in: selectionRect).values.contains { $0.contains(pointInView) }
    }
}
