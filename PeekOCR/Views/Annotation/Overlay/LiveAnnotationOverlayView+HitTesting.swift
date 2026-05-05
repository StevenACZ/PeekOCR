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
        let buttonSize = CGSize(width: 78, height: 42)
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(LiveAnnotationTool.allCases.count) * buttonSize.width + CGFloat(LiveAnnotationTool.allCases.count - 1) * spacing
        let origin = CGPoint(
            x: selectionRect.midX - totalWidth / 2,
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
            case .select:
                break
            }
        }
        return nil
    }

    func hitTestAnnotationResizeHandle(for annotation: LiveAnnotation, at point: CGPoint) -> SelectionHandle? {
        guard annotation.tool == .highlight else { return nil }

        for handle in SelectionHandle.allCases {
            let handleRect = CGRect(origin: handle.point(for: annotation.bounds), size: .zero)
                .insetBy(dx: -12, dy: -12)
            if handleRect.contains(point) {
                return handle
            }
        }

        return nil
    }
}
