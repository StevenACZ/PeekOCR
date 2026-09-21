// Live annotation overlay drawing and toolbar layout.

import AppKit

extension LiveAnnotationOverlayView {
    private static let toolbarIcons: [LiveAnnotationTool: NSImage] = {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            .applying(.init(paletteColors: [.white]))
        return Dictionary(
            uniqueKeysWithValues: LiveAnnotationTool.allCases.compactMap { tool in
                guard
                    let icon = NSImage(systemSymbolName: tool.iconName, accessibilityDescription: nil)?
                        .withSymbolConfiguration(configuration)
                else { return nil }
                return (tool, icon)
            })
    }()

    private static let shortcutParagraph: NSParagraphStyle = {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return paragraph
    }()

    private static let controlShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = CGSize(width: 0, height: -4)
        return shadow
    }()

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let window else { return }

        NSColor.clear.setFill()
        dirtyRect.fill()
        drawFrozenBackgroundIfNeeded()

        if let selectionRectInScreen {
            let selectionRect = convert(window.convertFromScreen(selectionRectInScreen), from: nil)
            let overlayPath = NSBezierPath(rect: bounds)
            overlayPath.appendRect(selectionRect)
            overlayPath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.32).setFill()
            overlayPath.fill()

            let border = NSBezierPath(rect: selectionRect)
            NSColor.black.withAlphaComponent(0.32).setStroke()
            border.lineWidth = 3
            border.stroke()
            NSColor.white.withAlphaComponent(0.95).setStroke()
            border.lineWidth = 1
            border.stroke()

            if mode == .quickSelect {
                drawSelectionSizeBadge(in: selectionRect)
            } else {
                drawSelectionHandles(in: selectionRect)
                LiveAnnotationRenderer.drawOverlayAnnotations(
                    annotationsForDrawing, in: self, window: window, selectionRectInScreen: selectionRectInScreen)
                drawSelectedAnnotationIfNeeded(in: self, window: window)
                drawToolbar(in: selectionRect)
                drawInstructions(in: selectionRect)
            }
        } else {
            NSColor.black.withAlphaComponent(0.25).setFill()
            bounds.fill()
            if mode == .quickSelect {
                drawCenteredHint(text: "capture.hint_quick_select".localized)
            } else {
                drawCenteredHint(text: "capture.hint_select_area".localized)
            }
        }
    }

    func drawFrozenBackgroundIfNeeded() {
        guard let image = frozenBackgroundPreview else { return }
        image.draw(
            in: bounds,
            from: CGRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
    }

    /// Live "W × H" readout under the selection while picking a region.
    func drawSelectionSizeBadge(in selectionRect: CGRect) {
        let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: min(max(selectionRect.maxX - size.width - 18, 8), max(8, bounds.maxX - size.width - 22)),
            y: max(selectionRect.minY - 26, 8),
            width: size.width + 14,
            height: size.height + 6
        )
        drawControlSurface(in: rect, radius: 10)
        (text as NSString).draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 3), withAttributes: attributes)
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

        drawControlSurface(in: background, radius: 18)

        for tool in LiveAnnotationTool.allCases {
            guard let frame = buttons[tool] else { continue }
            let selected = tool == selectedTool
            let fill = selected ? accentColor : NSColor.white.withAlphaComponent(0.045)
            fill.setFill()
            NSBezierPath(roundedRect: frame, xRadius: 9, yRadius: 9).fill()

            if let icon = Self.toolbarIcons[tool] {
                let iconRect = CGRect(
                    x: frame.midX - icon.size.width / 2,
                    y: frame.maxY - icon.size.height - 7,
                    width: icon.size.width,
                    height: icon.size.height
                )
                icon.draw(in: iconRect)
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(selected ? 0.95 : 0.7),
                .paragraphStyle: Self.shortcutParagraph,
            ]
            (tool.shortcutKey as NSString).draw(
                in: CGRect(x: frame.minX, y: frame.minY + 4, width: frame.width, height: 12),
                withAttributes: attributes
            )
        }
    }

    func drawInstructions(in selectionRect: CGRect) {
        let text =
            isEditingText
            ? "capture.instructions_text_editing".localized
            : "capture.instructions_default".localized
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: min(max(selectionRect.minX + 12, 8), max(8, bounds.maxX - size.width - 28)),
            y: max(selectionRect.minY - 34, 16),
            width: size.width + 20,
            height: size.height + 10
        )
        drawControlSurface(in: rect, radius: 10)
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
        drawControlSurface(in: rect, radius: 14)
        (text as NSString).draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 8), withAttributes: attributes)
    }

    private func drawControlSurface(in rect: CGRect, radius: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        Self.controlShadow.set()
        NSColor(calibratedWhite: 0.12, alpha: 0.96).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func drawSelectedAnnotationIfNeeded(in view: NSView, window: NSWindow) {
        guard let selectedAnnotationID,
            let annotation = annotations.first(where: { $0.id == selectedAnnotationID })
        else { return }

        let rectInView = rectInView(from: annotation.bounds).insetBy(dx: -6, dy: -6)
        let path = NSBezierPath(roundedRect: rectInView, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()

        drawAnnotationResizeHandles(for: annotation)
    }

    func drawAnnotationResizeHandles(for annotation: LiveAnnotation) {
        switch annotation.tool {
        case .arrow:
            drawHandleDot(at: annotation.startPoint, accent: annotation.color)
            drawHandleDot(at: annotation.endPoint, accent: annotation.color)
        case .highlight, .text, .pen:
            for handle in SelectionHandle.allCases {
                drawHandleDot(at: handle.point(for: annotation.bounds), accent: annotation.color)
            }
        case .select:
            break
        }
    }

    private func drawHandleDot(at screenPoint: CGPoint, accent: NSColor) {
        let point = viewPoint(from: screenPoint)
        let handleRect = CGRect(
            x: point.x - annotationHandleSize / 2,
            y: point.y - annotationHandleSize / 2,
            width: annotationHandleSize,
            height: annotationHandleSize
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: handleRect).fill()
        accent.setStroke()
        let stroke = NSBezierPath(ovalIn: handleRect)
        stroke.lineWidth = 1.5
        stroke.stroke()
    }
}
