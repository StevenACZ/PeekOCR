import AppKit
import CoreGraphics
import CoreText

/// Shared drawing/rendering helpers for live pre-capture annotations.
enum LiveAnnotationRenderer {
    static func drawOverlayAnnotations(
        _ annotations: [LiveAnnotation],
        in view: NSView,
        window: NSWindow,
        selectionRectInScreen: CGRect
    ) {
        NSGraphicsContext.saveGraphicsState()
        let selectionRect = view.convert(window.convertFromScreen(selectionRectInScreen), from: nil)
        let clipPath = NSBezierPath(rect: selectionRect)
        clipPath.addClip()

        for annotation in annotations {
            drawOverlayAnnotation(annotation, in: view, window: window)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    static func render(
        image: CGImage,
        selectionRectInScreen: CGRect,
        scaleFactor: CGFloat,
        annotations: [LiveAnnotation]
    ) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        let outputRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: outputRect)

        for annotation in annotations {
            drawRenderedAnnotation(
                annotation,
                in: context,
                selectionRectInScreen: selectionRectInScreen,
                scaleFactor: scaleFactor
            )
        }

        return context.makeImage()
    }

    private static func drawOverlayAnnotation(_ annotation: LiveAnnotation, in view: NSView, window: NSWindow) {
        switch annotation.tool {
        case .arrow:
            drawOverlayArrow(annotation, in: view, window: window)
        case .text:
            drawOverlayText(annotation, in: view, window: window)
        case .highlight:
            drawOverlayHighlight(annotation, in: view, window: window)
        case .select:
            break
        }
    }

    private static func drawOverlayArrow(_ annotation: LiveAnnotation, in view: NSView, window: NSWindow) {
        let start = pointInView(annotation.startPoint, view: view, window: window)
        let end = pointInView(annotation.endPoint, view: view, window: window)

        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = annotation.strokeWidth
        path.lineCapStyle = .round
        annotation.color.setStroke()
        path.stroke()

        let arrowhead = createArrowhead(from: start, to: end, size: max(annotation.strokeWidth * 4, 10))
        annotation.color.setFill()
        arrowhead.fill()
    }

    private static func drawOverlayHighlight(_ annotation: LiveAnnotation, in view: NSView, window: NSWindow) {
        let rect = rectInView(annotation.bounds, view: view, window: window).integral
        let fill = annotation.color.withAlphaComponent(0.2)
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

        annotation.color.setStroke()
        let stroke = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        stroke.lineWidth = annotation.strokeWidth
        stroke.stroke()
    }

    private static func drawOverlayText(_ annotation: LiveAnnotation, in view: NSView, window: NSWindow) {
        guard !annotation.text.isEmpty else { return }
        let rect = rectInView(annotation.bounds, view: view, window: window)
        let attributes = LiveAnnotation.textAttributes(fontSize: annotation.fontSize, color: annotation.color)
        (annotation.text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes)
    }

    private static func drawRenderedAnnotation(
        _ annotation: LiveAnnotation,
        in context: CGContext,
        selectionRectInScreen: CGRect,
        scaleFactor: CGFloat
    ) {
        switch annotation.tool {
        case .arrow:
            drawRenderedArrow(annotation, in: context, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)
        case .text:
            drawRenderedText(annotation, in: context, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)
        case .highlight:
            drawRenderedHighlight(annotation, in: context, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)
        case .select:
            break
        }
    }

    private static func drawRenderedArrow(
        _ annotation: LiveAnnotation, in context: CGContext, selectionRectInScreen: CGRect, scaleFactor: CGFloat
    ) {
        let start = localPoint(annotation.startPoint, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)
        let end = localPoint(annotation.endPoint, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)

        context.saveGState()
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.cgColor)
        context.setLineWidth(annotation.strokeWidth * scaleFactor)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = max(annotation.strokeWidth * 4, 10) * scaleFactor
        let arrowAngle: CGFloat = .pi / 6
        let point1 = CGPoint(x: end.x - size * cos(angle - arrowAngle), y: end.y - size * sin(angle - arrowAngle))
        let point2 = CGPoint(x: end.x - size * cos(angle + arrowAngle), y: end.y - size * sin(angle + arrowAngle))
        context.move(to: end)
        context.addLine(to: point1)
        context.addLine(to: point2)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    private static func drawRenderedHighlight(
        _ annotation: LiveAnnotation, in context: CGContext, selectionRectInScreen: CGRect, scaleFactor: CGFloat
    ) {
        let rect = CGRect(
            x: (min(annotation.startPoint.x, annotation.endPoint.x) - selectionRectInScreen.minX) * scaleFactor,
            y: (min(annotation.startPoint.y, annotation.endPoint.y) - selectionRectInScreen.minY) * scaleFactor,
            width: abs(annotation.endPoint.x - annotation.startPoint.x) * scaleFactor,
            height: abs(annotation.endPoint.y - annotation.startPoint.y) * scaleFactor
        ).integral

        context.saveGState()
        context.setFillColor(annotation.color.withAlphaComponent(0.2).cgColor)
        context.fill(rect)
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.strokeWidth * scaleFactor)
        context.stroke(rect)
        context.restoreGState()
    }

    private static func drawRenderedText(
        _ annotation: LiveAnnotation, in context: CGContext, selectionRectInScreen: CGRect, scaleFactor: CGFloat
    ) {
        guard !annotation.text.isEmpty else { return }

        // Same NSStringDrawing path as the live overlay so font, layout, and
        // multi-line behavior match exactly (just scaled to image pixels).
        let scaledFontSize = annotation.fontSize * scaleFactor
        let textSize = LiveAnnotation.textSize(for: annotation.text, fontSize: scaledFontSize)
        let topLeft = localPoint(annotation.startPoint, selectionRectInScreen: selectionRectInScreen, scaleFactor: scaleFactor)
        let rect = CGRect(x: topLeft.x, y: topLeft.y - textSize.height, width: textSize.width, height: textSize.height)
        let attributes = LiveAnnotation.textAttributes(fontSize: scaledFontSize, color: annotation.color)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (annotation.text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func pointInView(_ point: CGPoint, view: NSView, window: NSWindow) -> CGPoint {
        let pointInWindow = window.convertFromScreen(CGRect(origin: point, size: .zero)).origin
        return view.convert(pointInWindow, from: nil)
    }

    private static func rectInView(_ rect: CGRect, view: NSView, window: NSWindow) -> CGRect {
        let windowRect = window.convertFromScreen(rect)
        return view.convert(windowRect, from: nil)
    }

    private static func localPoint(_ point: CGPoint, selectionRectInScreen: CGRect, scaleFactor: CGFloat) -> CGPoint {
        CGPoint(
            x: (point.x - selectionRectInScreen.minX) * scaleFactor,
            y: (point.y - selectionRectInScreen.minY) * scaleFactor
        )
    }

    private static func createArrowhead(from start: CGPoint, to end: CGPoint, size: CGFloat) -> NSBezierPath {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle: CGFloat = .pi / 6
        let point1 = CGPoint(x: end.x - size * cos(angle - arrowAngle), y: end.y - size * sin(angle - arrowAngle))
        let point2 = CGPoint(x: end.x - size * cos(angle + arrowAngle), y: end.y - size * sin(angle + arrowAngle))

        let path = NSBezierPath()
        path.move(to: end)
        path.line(to: point1)
        path.line(to: point2)
        path.close()
        return path
    }
}
