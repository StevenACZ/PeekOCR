// Live annotation overlay drawing and toolbar layout.

import AppKit

extension LiveAnnotationOverlayView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let window else { return }

        NSColor.clear.setFill()
        dirtyRect.fill()

        if let selectionRectInScreen {
            let selectionRect = convert(window.convertFromScreen(selectionRectInScreen), from: nil)
            let overlayPath = NSBezierPath(rect: bounds)
            overlayPath.appendRect(selectionRect)
            overlayPath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.35).setFill()
            overlayPath.fill()

            let border = NSBezierPath(roundedRect: selectionRect, xRadius: 8, yRadius: 8)
            accentColor.setStroke()
            border.lineWidth = 2
            border.stroke()

            drawSelectionHandles(in: selectionRect)
            LiveAnnotationRenderer.drawOverlayAnnotations(annotationsForDrawing, in: self, window: window, selectionRectInScreen: selectionRectInScreen)
            drawSelectedAnnotationIfNeeded(in: self, window: window)
            drawToolbar(in: selectionRect)
            drawInstructions(in: selectionRect)
        } else {
            NSColor.black.withAlphaComponent(0.12).setFill()
            bounds.fill()
            drawCenteredHint(text: "Arrastra para seleccionar • S mover/ajustar • A flecha • T texto • H highlight • Enter capturar • Esc cancelar")
        }
    }

    var annotationsForDrawing: [LiveAnnotation] {
        switch interaction {
        case .drawingAnnotation(let annotation):
            return annotations + [annotation]
        default:
            return annotations
        }
    }

    func drawSelectionHandles(in rect: CGRect) {
        SelectionHandle.allCases.forEach { handle in
            let point = viewPoint(from: handle.point(for: screenRect(from: rect)))
            let handleRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            accentColor.setStroke()
            let stroke = NSBezierPath(ovalIn: handleRect)
            stroke.lineWidth = 1.5
            stroke.stroke()
        }
    }

    func drawToolbar(in selectionRect: CGRect) {
        let buttons = toolbarButtonFrames(in: selectionRect)
        let background = buttons.values.reduce(into: CGRect.null) { partialResult, rect in
            partialResult = partialResult.union(rect)
        }.insetBy(dx: -8, dy: -8).standardized
        guard !background.isNull else { return }

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: background, xRadius: 12, yRadius: 12).fill()

        for tool in LiveAnnotationTool.allCases {
            guard let frame = buttons[tool] else { continue }
            let selected = tool == selectedTool
            let fill = selected ? accentColor.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.08)
            fill.setFill()
            NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
            ]
            let title = "\(tool.displayName)\n\(tool.shortcutKey)"
            title.draw(in: frame.insetBy(dx: 6, dy: 8), withAttributes: attributes)
        }
    }

    func drawInstructions(in selectionRect: CGRect) {
        let text = "Arrastra bordes para ajustar • Arrastra dentro para mover • Enter captura • Esc cancela"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: selectionRect.minX + 12,
            y: max(selectionRect.minY - 34, 16),
            width: size.width + 20,
            height: size.height + 10
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5), withAttributes: attributes)
    }

    func drawCenteredHint(text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: bounds.midX - size.width / 2 - 14,
            y: bounds.midY - size.height / 2 - 8,
            width: size.width + 28,
            height: size.height + 16
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 8), withAttributes: attributes)
    }

    func drawSelectedAnnotationIfNeeded(in view: NSView, window: NSWindow) {
        guard let selectedAnnotationID,
              let annotation = annotations.first(where: { $0.id == selectedAnnotationID }) else { return }

        let rectInView = rectInView(from: annotation.bounds).insetBy(dx: -6, dy: -6)
        let path = NSBezierPath(roundedRect: rectInView, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()

        if annotation.tool == .highlight {
            drawAnnotationResizeHandles(for: annotation)
        }
    }

    func drawAnnotationResizeHandles(for annotation: LiveAnnotation) {
        for handle in SelectionHandle.allCases {
            let point = viewPoint(from: handle.point(for: annotation.bounds))
            let handleRect = CGRect(
                x: point.x - annotationHandleSize / 2,
                y: point.y - annotationHandleSize / 2,
                width: annotationHandleSize,
                height: annotationHandleSize
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            annotation.color.setStroke()
            let stroke = NSBezierPath(ovalIn: handleRect)
            stroke.lineWidth = 1.5
            stroke.stroke()
        }
    }
}
