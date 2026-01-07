//
//  CGContextAnnotationRenderer.swift
//  PeekOCR
//
//  Renders annotations to CGContext for image export.
//

import AppKit
import CoreGraphics
import CoreText
import SwiftUI

/// Renders annotations to a CGContext for exporting images
enum CGContextAnnotationRenderer {
    // MARK: - Main Render

    /// Renders all annotations to a CGContext
    /// - Parameters:
    ///   - annotations: The annotations to render
    ///   - context: The CGContext to draw on
    ///   - imageSize: The size of the output image
    ///   - canvasSize: The canvas size used during editing
    static func render(
        annotations: [Annotation],
        to context: CGContext,
        imageSize: CGSize,
        canvasSize: CGSize
    ) {
        let imageRect = AnnotationGeometry.calculateImageRect(imageSize: imageSize, canvasSize: canvasSize)
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height

        for annotation in annotations {
            drawAnnotation(
                annotation,
                context: context,
                scaleX: scaleX,
                scaleY: scaleY,
                height: imageSize.height,
                imageRect: imageRect
            )
        }
    }

    // MARK: - Dispatch

    private static func drawAnnotation(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        let cgColor = NSColor(annotation.color).cgColor

        context.setStrokeColor(cgColor)
        context.setFillColor(cgColor)
        context.setLineWidth(annotation.strokeWidth * scaleX)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .select:
            break
        case .arrow:
            drawArrow(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .text:
            drawText(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .freehand:
            drawFreehand(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .rectangle:
            drawRectangle(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .oval:
            drawOval(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        }
    }

    // MARK: - Arrow

    private static func drawArrow(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        let start = transformPoint(annotation.startPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        let end = transformPoint(annotation.endPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)

        // Draw line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowSize = annotation.strokeWidth * 4 * scaleX
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - arrowSize * cos(angle - arrowAngle),
            y: end.y - arrowSize * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowSize * cos(angle + arrowAngle),
            y: end.y - arrowSize * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: point1)
        context.addLine(to: point2)
        context.closePath()
        context.fillPath()
    }

    // MARK: - Text

    private static func drawText(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        guard !annotation.text.isEmpty else { return }

        let x = (annotation.startPoint.x - imageRect.minX) * scaleX
        let scaledFontSize = annotation.fontSize * scaleX
        let y = height - ((annotation.startPoint.y - imageRect.minY) * scaleY) - scaledFontSize

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, scaledFontSize, nil)
        let cgColor = NSColor(annotation.color).cgColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: cgColor
        ]

        let attributedString = NSAttributedString(string: annotation.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Freehand

    private static func drawFreehand(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        guard annotation.points.count > 1 else { return }

        let scaledPoints = annotation.points.map { point in
            transformPoint(point, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        }

        context.move(to: scaledPoints[0])
        for point in scaledPoints.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    // MARK: - Rectangle

    private static func drawRectangle(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        let p1 = transformPoint(annotation.startPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        let p2 = transformPoint(annotation.endPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)

        let rect = CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )

        context.stroke(rect)
    }

    // MARK: - Oval

    private static func drawOval(
        _ annotation: Annotation,
        context: CGContext,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) {
        let p1 = transformPoint(annotation.startPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        let p2 = transformPoint(annotation.endPoint, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)

        let rect = CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )

        context.strokeEllipse(in: rect)
    }

    // MARK: - Helpers

    private static func transformPoint(
        _ point: CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat,
        height: CGFloat,
        imageRect: CGRect
    ) -> CGPoint {
        CGPoint(
            x: (point.x - imageRect.minX) * scaleX,
            y: height - ((point.y - imageRect.minY) * scaleY)
        )
    }
}
