// Live annotation overlay hit testing and toolbar selection.

import AppKit

extension LiveAnnotationOverlayView {
    func handleToolbarClick(at pointInScreen: CGPoint) -> Bool {
        guard let selectionRectInScreen else { return false }
        let selectionRect = convert(window?.convertFromScreen(selectionRectInScreen) ?? .zero, from: nil)
        let pointInView = viewPoint(from: pointInScreen)

        for (tool, frame) in toolbarButtonFrames(in: selectionRect) where frame.contains(pointInView) {
            selectedTool = tool
            needsDisplay = true
            return true
        }

        return false
    }

    func toolbarButtonFrames(in selectionRect: CGRect) -> [LiveAnnotationTool: CGRect] {
        let buttonSize = CGSize(width: 64, height: 46)
        let spacing: CGFloat = 8
        let totalWidth =
            CGFloat(LiveAnnotationTool.allCases.count) * buttonSize.width + CGFloat(LiveAnnotationTool.allCases.count - 1) * spacing
        let unclampedX = selectionRect.midX - totalWidth / 2
        let origin = CGPoint(
            x: min(max(unclampedX, 16), bounds.maxX - totalWidth - 16),
            y: min(selectionRect.maxY + 14, bounds.maxY - buttonSize.height - 20)
        )

        var frames: [LiveAnnotationTool: CGRect] = [:]
        for (index, tool) in LiveAnnotationTool.allCases.enumerated() {
            frames[tool] = CGRect(
                x: origin.x + CGFloat(index) * (buttonSize.width + spacing),
                y: origin.y,
                width: buttonSize.width,
                height: buttonSize.height
            )
        }
        return frames
    }

    func hitTestHandle(at point: CGPoint, selectionRectInScreen: CGRect) -> SelectionHandle? {
        for handle in SelectionHandle.allCases {
            let handleRect = CGRect(origin: handle.point(for: selectionRectInScreen), size: .zero).insetBy(dx: -10, dy: -10)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    func hitTestAnnotation(at point: CGPoint) -> UUID? {
        for annotation in annotations.reversed() {
            switch annotation.tool {
            case .arrow:
                if HitTestEngine.hitTestLine(from: annotation.startPoint, to: annotation.endPoint, point: point, tolerance: 12) {
                    return annotation.id
                }
            case .highlight:
                if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
                    return annotation.id
                }
            case .text:
                if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
                    return annotation.id
                }
            case .pen:
                for (segmentStart, segmentEnd) in zip(annotation.points, annotation.points.dropFirst()) {
                    if HitTestEngine.hitTestLine(from: segmentStart, to: segmentEnd, point: point, tolerance: 10) {
                        return annotation.id
                    }
                }
            case .select:
                break
            }
        }
        return nil
    }

    func hitTestAnnotationResizeHandle(for annotation: LiveAnnotation, at point: CGPoint) -> AnnotationHandle? {
        let grabRadius: CGFloat = 12

        switch annotation.tool {
        case .arrow:
            if CGRect(origin: annotation.startPoint, size: .zero).insetBy(dx: -grabRadius, dy: -grabRadius).contains(point) {
                return .arrowStart
            }
            if CGRect(origin: annotation.endPoint, size: .zero).insetBy(dx: -grabRadius, dy: -grabRadius).contains(point) {
                return .arrowEnd
            }
            return nil
        case .highlight, .text, .pen:
            for handle in SelectionHandle.allCases {
                let handleRect = CGRect(origin: handle.point(for: annotation.bounds), size: .zero)
                    .insetBy(dx: -grabRadius, dy: -grabRadius)
                if handleRect.contains(point) {
                    return .corner(handle)
                }
            }
            return nil
        case .select:
            return nil
        }
    }
}
