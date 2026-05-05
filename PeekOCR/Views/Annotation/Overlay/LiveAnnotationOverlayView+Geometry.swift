// Live annotation overlay geometry transforms and history helpers.

import AppKit

extension LiveAnnotationOverlayView {
    func updateAnnotation(id: UUID, with updatedAnnotation: LiveAnnotation) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = updatedAnnotation
    }

    func recordAnnotationSnapshot() {
        annotationHistory.append(annotations)
        if annotationHistory.count > maxAnnotationHistory {
            annotationHistory.removeFirst(annotationHistory.count - maxAnnotationHistory)
        }
    }

    func undoLastAnnotationChange() {
        removeTextField(commit: false)
        guard let previousAnnotations = annotationHistory.popLast() else { return }
        annotations = previousAnnotations
        if let selectedAnnotationID,
            !annotations.contains(where: { $0.id == selectedAnnotationID })
        {
            self.selectedAnnotationID = nil
        }
        interaction = .none
    }

    func translated(annotation: LiveAnnotation, dx: CGFloat, dy: CGFloat) -> LiveAnnotation {
        var annotation = annotation
        annotation.startPoint.x += dx
        annotation.startPoint.y += dy
        annotation.endPoint.x += dx
        annotation.endPoint.y += dy
        return annotation
    }

    func resize(annotation: LiveAnnotation, handle: SelectionHandle, point: CGPoint) -> LiveAnnotation {
        var minX = annotation.bounds.minX
        var maxX = annotation.bounds.maxX
        var minY = annotation.bounds.minY
        var maxY = annotation.bounds.maxY

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

        if maxX - minX < minimumHighlightSize.width {
            if handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minimumHighlightSize.width
            } else {
                maxX = minX + minimumHighlightSize.width
            }
        }

        if maxY - minY < minimumHighlightSize.height {
            if handle == .bottomLeft || handle == .bottomRight {
                minY = maxY - minimumHighlightSize.height
            } else {
                maxY = minY + minimumHighlightSize.height
            }
        }

        var resizedAnnotation = annotation
        resizedAnnotation.startPoint = CGPoint(x: minX, y: minY)
        resizedAnnotation.endPoint = CGPoint(x: maxX, y: maxY)
        return resizedAnnotation
    }

    func resize(initialRect: CGRect, handle: SelectionHandle, point: CGPoint) -> CGRect {
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

        if maxX - minX < minimumSelectionSize.width {
            if handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minimumSelectionSize.width
            } else {
                maxX = minX + minimumSelectionSize.width
            }
        }

        if maxY - minY < minimumSelectionSize.height {
            if handle == .bottomLeft || handle == .bottomRight {
                minY = maxY - minimumSelectionSize.height
            } else {
                maxY = minY + minimumSelectionSize.height
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func translated(_ annotations: [LiveAnnotation], dx: CGFloat, dy: CGFloat) -> [LiveAnnotation] {
        annotations.map { annotation in
            var annotation = annotation
            annotation.startPoint.x += dx
            annotation.startPoint.y += dy
            annotation.endPoint.x += dx
            annotation.endPoint.y += dy
            return annotation
        }
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
