// Live annotation overlay drawing and toolbar layout.

import AppKit

extension LiveAnnotationOverlayView {
    private static func symbol(_ name: String, color: NSColor, weight: NSFont.Weight = .medium) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: weight)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    private static let toolbarIcons: [LiveAnnotationTool: NSImage] = Dictionary(
        uniqueKeysWithValues: LiveAnnotationTool.allCases.compactMap { tool in
            symbol(tool.iconName, color: .white).map { (tool, $0) }
        })

    private static let cancelIcon = symbol("xmark", color: .white, weight: .semibold)
    private static let captureIcon = symbol("checkmark", color: .black, weight: .bold)

    private static let controlShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = CGSize(width: 0, height: -3)
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
                let layout = toolbarLayout(in: selectionRect)
                drawToolbar(layout)
                drawToolbarCaption(for: layout)
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

    func drawToolbar(_ layout: ToolbarLayout) {
        drawControlSurface(in: layout.background, radius: 12)
        NSColor.white.withAlphaComponent(0.16).setFill()
        layout.separator.fill()

        for (item, frame) in layout.items {
            let hovered = item == hoveredToolbarItem
            let icon: NSImage?
            switch item {
            case .tool(let tool):
                let selected = tool == selectedTool
                if selected {
                    fillButton(frame, color: accentColor)
                } else if hovered {
                    fillButton(frame, color: NSColor.white.withAlphaComponent(0.1))
                }
                icon = Self.toolbarIcons[tool]
                drawShortcutKey(tool.shortcutKey, in: frame, emphasized: selected)
            case .cancel:
                if hovered {
                    fillButton(frame, color: NSColor.white.withAlphaComponent(0.1))
                }
                icon = Self.cancelIcon
            case .capture:
                fillButton(frame, color: NSColor.white.withAlphaComponent(hovered ? 1 : 0.9))
                icon = Self.captureIcon
            }

            if let icon {
                icon.draw(
                    in: CGRect(
                        x: (frame.midX - icon.size.width / 2).rounded(),
                        y: (frame.midY - icon.size.height / 2).rounded(),
                        width: icon.size.width,
                        height: icon.size.height
                    ))
            }
        }
    }

    private func fillButton(_ frame: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()
    }

    private func drawShortcutKey(_ key: String, in frame: CGRect, emphasized: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.5, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(emphasized ? 0.85 : 0.4),
        ]
        let size = (key as NSString).size(withAttributes: attributes)
        (key as NSString).draw(
            at: CGPoint(x: frame.maxX - size.width - 3, y: frame.minY + 1.5), withAttributes: attributes)
    }

    /// One small chip on the outer side of the toolbar: the text-editing keys
    /// while typing, otherwise the name and shortcut of the hovered button.
    func drawToolbarCaption(for layout: ToolbarLayout) {
        let caption: (title: String, key: String?, anchorX: CGFloat)
        if isEditingText {
            caption = ("capture.instructions_text_editing".localized, nil, layout.background.midX)
        } else if let item = hoveredToolbarItem, let frame = layout.frame(for: item) {
            switch item {
            case .tool(let tool):
                caption = (tool.displayName, tool.shortcutKey, frame.midX)
            case .cancel:
                caption = ("common.cancel".localized, "esc", frame.midX)
            case .capture:
                caption = ("capture.toolbar_capture".localized, "↩", frame.midX)
            }
        } else {
            return
        }

        let text = NSMutableAttributedString(
            string: caption.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white,
            ])
        if let key = caption.key {
            text.append(
                NSAttributedString(
                    string: "  \(key)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: NSColor.white.withAlphaComponent(0.5),
                    ]))
        }

        let textSize = text.size()
        let size = CGSize(width: ceil(textSize.width) + 16, height: ceil(textSize.height) + 8)
        let safe = controlSafeRect
        let gap: CGFloat = 6
        let belowY = layout.background.minY - gap - size.height
        let aboveY = layout.background.maxY + gap
        let prefersBelow = layout.placement == .below
        let y: CGFloat
        if prefersBelow {
            y = belowY >= safe.minY ? belowY : aboveY
        } else {
            y = aboveY + size.height <= safe.maxY ? aboveY : belowY
        }
        let x = min(max(caption.anchorX - size.width / 2, safe.minX), safe.maxX - size.width)
        let rect = CGRect(origin: CGPoint(x: x.rounded(), y: y.rounded()), size: size)

        drawControlSurface(in: rect, radius: 7)
        text.draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 4))
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
        NSColor(calibratedWhite: 0.1, alpha: 0.94).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.12).setStroke()
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
