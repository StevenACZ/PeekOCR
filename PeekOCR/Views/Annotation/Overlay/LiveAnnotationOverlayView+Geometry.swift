// Live annotation overlay geometry transforms and history helpers.

import AppKit

extension LiveAnnotationOverlayView {
    func updateAnnotation(id: UUID, with updatedAnnotation: LiveAnnotation) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = updatedAnnotation
    }

    /// Captures the state at the start of a drag interaction. The snapshot only
    /// becomes an undo step if the interaction actually changed something —
    /// otherwise ⌘Z would silently "undo" no-op clicks.
    func beginAnnotationTransaction() {
        pendingUndoSnapshot = annotations
    }

    func commitAnnotationTransaction() {
        guard let snapshot = pendingUndoSnapshot else { return }
        pendingUndoSnapshot = nil
        guard snapshot != annotations else { return }
        pushUndoSnapshot(snapshot)
    }

    /// Records an atomic change (add, delete, text edit). `snapshot` is the state
    /// BEFORE the change. Any new change invalidates the redo stack.
    func pushUndoSnapshot(_ snapshot: [LiveAnnotation]) {
        annotationHistory.append(snapshot)
        if annotationHistory.count > maxAnnotationHistory {
            annotationHistory.removeFirst(annotationHistory.count - maxAnnotationHistory)
        }
        annotationRedoStack.removeAll()
    }

    func undoLastAnnotationChange() {
        dismissTextEditor(commit: false)
        pendingUndoSnapshot = nil
        guard let previousAnnotations = annotationHistory.popLast() else { return }
        annotationRedoStack.append(annotations)
        annotations = previousAnnotations
        clearSelectionIfMissing()
        interaction = .none
    }

    func redoLastAnnotationChange() {
        dismissTextEditor(commit: false)
        pendingUndoSnapshot = nil
        guard let nextAnnotations = annotationRedoStack.popLast() else { return }
        annotationHistory.append(annotations)
        annotations = nextAnnotations
        clearSelectionIfMissing()
        interaction = .none
    }

    func deleteSelectedAnnotation() {
        guard let selectedAnnotationID else { return }
        deleteAnnotation(id: selectedAnnotationID)
    }

    func deleteAnnotation(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        pushUndoSnapshot(annotations)
        annotations.remove(at: index)
        if selectedAnnotationID == id {
            selectedAnnotationID = nil
        }
        interaction = .none
    }

    private func clearSelectionIfMissing() {
        if let selectedAnnotationID,
            !annotations.contains(where: { $0.id == selectedAnnotationID })
        {
            self.selectedAnnotationID = nil
        }
    }

    func translated(annotation: LiveAnnotation, dx: CGFloat, dy: CGFloat) -> LiveAnnotation {
        var annotation = annotation
        annotation.startPoint.x += dx
        annotation.startPoint.y += dy
        annotation.endPoint.x += dx
        annotation.endPoint.y += dy
        annotation.points = annotation.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        return annotation
    }

    func resize(annotation: LiveAnnotation, handle: AnnotationHandle, point: CGPoint) -> LiveAnnotation {
        switch handle {
        case .arrowStart:
            var updated = annotation
            updated.startPoint = point
            return updated
        case .arrowEnd:
            var updated = annotation
            updated.endPoint = point
            return updated
        case .corner(let corner):
            switch annotation.tool {
            case .highlight:
                return resizeRectAnnotation(annotation, corner: corner, point: point)
            case .text:
                return resizeTextAnnotation(annotation, corner: corner, point: point)
            case .pen:
                return resizePenAnnotation(annotation, corner: corner, point: point)
            case .arrow, .select:
                return annotation
            }
        }
    }

    private func resizeRectAnnotation(_ annotation: LiveAnnotation, corner: SelectionHandle, point: CGPoint) -> LiveAnnotation {
        let newRect = resize(
            initialRect: annotation.bounds, handle: corner, point: point, minimumSize: minimumHighlightSize)
        var updated = annotation
        updated.startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
        updated.endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
        return updated
    }

    /// Dragging a corner scales the font; the opposite corner stays anchored.
    /// The scale tracks the cursor's diagonal distance to the anchor, so the
    /// grabbed corner follows the mouse instead of racing ahead of it.
    private func resizeTextAnnotation(_ annotation: LiveAnnotation, corner: SelectionHandle, point: CGPoint) -> LiveAnnotation {
        let initialBounds = annotation.bounds
        guard initialBounds.width > 0, initialBounds.height > 0 else { return annotation }

        let anchor = corner.opposite.point(for: initialBounds)
        let initialDiagonal = hypot(initialBounds.width, initialBounds.height)
        let newDiagonal = hypot(point.x - anchor.x, point.y - anchor.y)
        guard initialDiagonal > 0 else { return annotation }
        let scale = newDiagonal / initialDiagonal
        let newFontSize = min(max(annotation.fontSize * scale, 9), 160)

        var updated = annotation
        updated.fontSize = newFontSize
        let newSize = LiveAnnotation.textSize(for: updated.text, fontSize: newFontSize)

        switch corner {
        case .bottomRight:
            updated.startPoint = anchor
        case .bottomLeft:
            updated.startPoint = CGPoint(x: anchor.x - newSize.width, y: anchor.y)
        case .topRight:
            updated.startPoint = CGPoint(x: anchor.x, y: anchor.y + newSize.height)
        case .topLeft:
            updated.startPoint = CGPoint(x: anchor.x - newSize.width, y: anchor.y + newSize.height)
        }
        updated.endPoint = updated.startPoint
        return updated
    }

    private func resizePenAnnotation(_ annotation: LiveAnnotation, corner: SelectionHandle, point: CGPoint) -> LiveAnnotation {
        let initialBounds = annotation.bounds
        guard initialBounds.width > 0, initialBounds.height > 0 else { return annotation }

        let newRect = resize(
            initialRect: initialBounds, handle: corner, point: point,
            minimumSize: CGSize(width: 12, height: 12))
        var updated = annotation
        updated.points = annotation.points.map { transform(point: $0, from: initialBounds, to: newRect) }
        updated.startPoint = updated.points.first ?? updated.startPoint
        updated.endPoint = updated.points.last ?? updated.endPoint
        return updated
    }

    func resize(initialRect: CGRect, handle: SelectionHandle, point: CGPoint, minimumSize: CGSize? = nil) -> CGRect {
        let minSize = minimumSize ?? minimumSelectionSize
        var minX = initialRect.minX
        var maxX = initialRect.maxX
        var minY = initialRect.minY
        var maxY = initialRect.maxY

        switch handle {
        case .topLeft:
            minX = point.x
            maxY = point.y
        case .topRight:
            maxX = point.x
            maxY = point.y
        case .bottomLeft:
            minX = point.x
            minY = point.y
        case .bottomRight:
            maxX = point.x
            minY = point.y
        }

        if maxX - minX < minSize.width {
            if handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minSize.width
            } else {
                maxX = minX + minSize.width
            }
        }

        if maxY - minY < minSize.height {
            if handle == .bottomLeft || handle == .bottomRight {
                minY = maxY - minSize.height
            } else {
                maxY = minY + minSize.height
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func translated(_ annotations: [LiveAnnotation], dx: CGFloat, dy: CGFloat) -> [LiveAnnotation] {
        annotations.map { translated(annotation: $0, dx: dx, dy: dy) }
    }

    func transformed(_ annotations: [LiveAnnotation], from initialRect: CGRect, to newRect: CGRect) -> [LiveAnnotation] {
        guard initialRect.width > 0, initialRect.height > 0 else { return annotations }
        let scaleX = newRect.width / initialRect.width
        let scaleY = newRect.height / initialRect.height
        let fontScale = max(0.75, min(scaleX, scaleY))

        return annotations.map { annotation in
            var annotation = annotation
            annotation.startPoint = transform(point: annotation.startPoint, from: initialRect, to: newRect)
            annotation.endPoint = transform(point: annotation.endPoint, from: initialRect, to: newRect)
            annotation.points = annotation.points.map { transform(point: $0, from: initialRect, to: newRect) }
            if annotation.tool == .text {
                annotation.fontSize *= fontScale
            }
            return annotation
        }
    }

    func transform(point: CGPoint, from initialRect: CGRect, to newRect: CGRect) -> CGPoint {
        let relativeX = (point.x - initialRect.minX) / initialRect.width
        let relativeY = (point.y - initialRect.minY) / initialRect.height
        return CGPoint(
            x: newRect.minX + relativeX * newRect.width,
            y: newRect.minY + relativeY * newRect.height
        )
    }

    func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    func clamp(rect: CGRect, to bounds: CGRect) -> CGRect {
        var rect = rect
        if rect.minX < bounds.minX { rect.origin.x = bounds.minX }
        if rect.minY < bounds.minY { rect.origin.y = bounds.minY }
        if rect.maxX > bounds.maxX { rect.origin.x = bounds.maxX - rect.width }
        if rect.maxY > bounds.maxY { rect.origin.y = bounds.maxY - rect.height }
        return rect
    }

    func screenPoint(from pointInWindow: CGPoint, window: NSWindow) -> CGPoint {
        window.convertToScreen(CGRect(origin: pointInWindow, size: .zero)).origin
    }

    func screenRect(from rectInView: CGRect) -> CGRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(rectInView, to: nil))
    }

    func viewPoint(from screenPoint: CGPoint) -> CGPoint {
        guard let window else { return .zero }
        let pointInWindow = window.convertFromScreen(CGRect(origin: screenPoint, size: .zero)).origin
        return convert(pointInWindow, from: nil)
    }

    func rectInView(from screenRect: CGRect) -> CGRect {
        guard let window else { return .zero }
        let rectInWindow = window.convertFromScreen(screenRect)
        return convert(rectInWindow, from: nil)
    }
}
