//
//  AnnotationRenderer.swift
//  PeekOCR
//
//  Dispatches drawing calls based on annotation tool type.
//

import SwiftUI

/// Renders annotations on a GraphicsContext
enum AnnotationRenderer {
    // MARK: - Main Dispatch

    /// Draws an annotation on the graphics context
    /// - Parameters:
    ///   - annotation: The annotation to draw
    ///   - context: The graphics context
    static func draw(_ annotation: Annotation, context: GraphicsContext) {
        let strokeStyle = StrokeStyle(
            lineWidth: annotation.strokeWidth,
            lineCap: .round,
            lineJoin: .round
        )
        let shading = GraphicsContext.Shading.color(annotation.color)

        switch annotation.tool {
        case .select:
            break // Select tool doesn't create annotations
        case .arrow:
            drawArrow(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .text:
            drawText(annotation, context: context)
        case .freehand:
            drawFreehand(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .rectangle:
            drawRectangle(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .oval:
            drawOval(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        }
    }

    // MARK: - Arrow

    private static func drawArrow(
        _ annotation: Annotation,
        context: GraphicsContext,
        strokeStyle: StrokeStyle,
        color: GraphicsContext.Shading
    ) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        // Draw the line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: color, style: strokeStyle)

        // Draw the arrowhead
        let arrowPath = createArrowhead(from: start, to: end, size: annotation.strokeWidth * 4)
        context.fill(arrowPath, with: color)
    }

    private static func createArrowhead(from start: CGPoint, to end: CGPoint, size: CGFloat) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees

        let point1 = CGPoint(
            x: end.x - size * cos(angle - arrowAngle),
            y: end.y - size * sin(angle - arrowAngle)
        )

        let point2 = CGPoint(
            x: end.x - size * cos(angle + arrowAngle),
            y: end.y - size * sin(angle + arrowAngle)
        )

        var path = Path()
        path.move(to: end)
        path.addLine(to: point1)
        path.addLine(to: point2)
        path.closeSubpath()

        return path
    }

    // MARK: - Text

    private static func drawText(_ annotation: Annotation, context: GraphicsContext) {
        guard !annotation.text.isEmpty else { return }

        let text = Text(annotation.text)
            .font(.system(size: annotation.fontSize, weight: .medium))
            .foregroundColor(annotation.color)

        context.draw(text, at: annotation.startPoint, anchor: .topLeading)
    }

    // MARK: - Freehand

    private static func drawFreehand(
        _ annotation: Annotation,
        context: GraphicsContext,
        strokeStyle: StrokeStyle,
        color: GraphicsContext.Shading
    ) {
        guard annotation.points.count > 1 else { return }

        var path = Path()
        path.move(to: annotation.points[0])

        for point in annotation.points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(path, with: color, style: strokeStyle)
    }

    // MARK: - Rectangle

    private static func drawRectangle(
        _ annotation: Annotation,
        context: GraphicsContext,
        strokeStyle: StrokeStyle,
        color: GraphicsContext.Shading
    ) {
        let rect = AnnotationGeometry.shapeRect(
            from: annotation.startPoint,
            to: annotation.endPoint
        )

        let path = Path(rect)
        context.stroke(path, with: color, style: strokeStyle)
    }

    // MARK: - Oval

    private static func drawOval(
        _ annotation: Annotation,
        context: GraphicsContext,
        strokeStyle: StrokeStyle,
        color: GraphicsContext.Shading
    ) {
        let rect = AnnotationGeometry.shapeRect(
            from: annotation.startPoint,
            to: annotation.endPoint
        )

        let path = Path(ellipseIn: rect)
        context.stroke(path, with: color, style: strokeStyle)
    }
}
