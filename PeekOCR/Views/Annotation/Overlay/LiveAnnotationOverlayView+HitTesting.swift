// Live annotation overlay hit testing and toolbar selection.

import AppKit

extension LiveAnnotationOverlayView {
    enum ToolbarItem: Equatable {
        case tool(LiveAnnotationTool)
        case cancel
        case capture
    }

    enum ToolbarPlacement {
        case below
        case above
        case inside
    }

    struct ToolbarLayout {
        let background: CGRect
        let separator: CGRect
        let items: [(item: ToolbarItem, frame: CGRect)]
        let placement: ToolbarPlacement

        func item(at point: CGPoint) -> ToolbarItem? {
            items.first { $0.frame.contains(point) }?.item
        }

        func frame(for item: ToolbarItem) -> CGRect? {
            items.first { $0.item == item }?.frame
        }
    }

    func handleToolbarClick(at pointInScreen: CGPoint) -> Bool {
        guard let layout = currentToolbarLayout() else { return false }
        let pointInView = viewPoint(from: pointInScreen)
        guard layout.background.contains(pointInView) else { return false }

        switch layout.item(at: pointInView) {
        case .tool(let tool):
            selectedTool = tool
        case .cancel:
            onCancel?()
        case .capture:
            if let selectionRectInScreen {
                onComplete?(selectionRectInScreen, overlayScreen, annotations)
            }
        case nil:
            break
        }
        needsDisplay = true
        return true
    }

    func currentToolbarLayout() -> ToolbarLayout? {
        guard mode == .annotate, let selectionRectInScreen else { return nil }
        return toolbarLayout(in: rectInView(from: selectionRectInScreen))
    }

    /// Area where floating controls may sit: the visible screen (no menu bar,
    /// notch or Dock) with a small margin.
    var controlSafeRect: CGRect {
        rectInView(from: overlayScreen.visibleFrame).intersection(bounds).insetBy(dx: 8, dy: 8)
    }

    /// Compact bar centered on the selection. It prefers the outside of the
    /// selection (below, then above) and only falls back inside it when the
    /// selection leaves no room on the screen.
    func toolbarLayout(in selectionRect: CGRect) -> ToolbarLayout {
        let buttonSide: CGFloat = 32
        let spacing: CGFloat = 2
        let padding: CGFloat = 5
        let separatorWidth: CGFloat = 13
        let gap: CGFloat = 10

        let tools = LiveAnnotationTool.allCases.map(ToolbarItem.tool)
        let actions: [ToolbarItem] = [.cancel, .capture]
        let buttonCount = CGFloat(tools.count + actions.count)
        let size = CGSize(
            width: padding * 2 + buttonCount * buttonSide + (buttonCount - 2) * spacing + separatorWidth,
            height: buttonSide + padding * 2
        )

        let safe = controlSafeRect
        let placement: ToolbarPlacement
        let y: CGFloat
        if selectionRect.minY - gap - size.height >= safe.minY {
            placement = .below
            y = selectionRect.minY - gap - size.height
        } else if selectionRect.maxY + gap + size.height <= safe.maxY {
            placement = .above
            y = selectionRect.maxY + gap
        } else {
            placement = .inside
            y = max(selectionRect.minY, safe.minY) + 12
        }
        let x = min(max(selectionRect.midX - size.width / 2, safe.minX), safe.maxX - size.width)
        let background = CGRect(origin: CGPoint(x: x.rounded(), y: y.rounded()), size: size)

        var items: [(item: ToolbarItem, frame: CGRect)] = []
        var cursor = background.minX + padding
        for (index, item) in tools.enumerated() {
            if index > 0 { cursor += spacing }
            items.append((item, CGRect(x: cursor, y: background.minY + padding, width: buttonSide, height: buttonSide)))
            cursor += buttonSide
        }
        let separator = CGRect(
            x: cursor + (separatorWidth - 1) / 2, y: background.minY + padding + 8, width: 1, height: buttonSide - 16)
        cursor += separatorWidth
        for (index, item) in actions.enumerated() {
            if index > 0 { cursor += spacing }
            items.append((item, CGRect(x: cursor, y: background.minY + padding, width: buttonSide, height: buttonSide)))
            cursor += buttonSide
        }

        return ToolbarLayout(background: background, separator: separator, items: items, placement: placement)
    }

    func updateToolbarHover(at pointInScreen: CGPoint) {
        guard let layout = currentToolbarLayout() else {
            hoveredToolbarItem = nil
            return
        }
        hoveredToolbarItem = layout.item(at: viewPoint(from: pointInScreen))
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
