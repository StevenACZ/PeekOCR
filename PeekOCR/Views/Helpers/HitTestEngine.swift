//
//  HitTestEngine.swift
//  PeekOCR
//
//  Collision detection for annotations and resize handles.
//

import Foundation
import CoreGraphics

/// Engine for hit testing annotations and handles
enum HitTestEngine {
    /// Default tolerance for hit testing
    static let defaultTolerance: CGFloat = 10

    // MARK: - Annotation Hit Testing

    /// Tests if a point hits an annotation
    /// - Parameters:
    ///   - annotation: The annotation to test
    ///   - point: The point to test
    ///   - tolerance: Hit tolerance (default: 10)
    /// - Returns: Whether the point hits the annotation
    static func hitTest(annotation: Annotation, at point: CGPoint, tolerance: CGFloat = defaultTolerance) -> Bool {
        switch annotation.tool {
        case .select:
            return false
        case .arrow:
            return hitTestLine(from: annotation.startPoint, to: annotation.endPoint, point: point, tolerance: tolerance)
        case .text:
            return hitTestText(annotation: annotation, point: point, tolerance: tolerance)
        case .freehand:
            return hitTestFreehand(points: annotation.points, point: point, tolerance: tolerance)
        case .rectangle, .oval:
            return hitTestShape(annotation: annotation, point: point, tolerance: tolerance)
        }
    }

    // MARK: - Handle Hit Testing

    /// Tests if a point hits a resize handle
    /// - Parameters:
    ///   - point: The point to test
    ///   - annotation: The annotation with handles
    /// - Returns: The hit handle, or nil
    static func hitTestHandle(at point: CGPoint, for annotation: Annotation) -> ResizeHandle? {
        let rect = AnnotationGeometry.boundingRect(for: annotation)

        for handle in ResizeHandle.allCases {
            let handleRect = AnnotationGeometry.handleRect(for: handle, in: rect)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    // MARK: - Line Hit Testing

    /// Tests if a point is near a line segment
    /// - Parameters:
    ///   - start: Line start point
    ///   - end: Line end point
    ///   - point: Point to test
    ///   - tolerance: Distance tolerance
    /// - Returns: Whether the point is within tolerance of the line
    static func hitTestLine(from start: CGPoint, to end: CGPoint, point: CGPoint, tolerance: CGFloat) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return hypot(point.x - start.x, point.y - start.y) <= tolerance
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let nearestX = start.x + t * dx
        let nearestY = start.y + t * dy
        let distance = hypot(point.x - nearestX, point.y - nearestY)

        return distance <= tolerance
    }

    // MARK: - Private Methods

    private static func hitTestText(annotation: Annotation, point: CGPoint, tolerance: CGFloat) -> Bool {
        let textRect = CGRect(
            x: annotation.startPoint.x,
            y: annotation.startPoint.y,
            width: CGFloat(annotation.text.count) * annotation.fontSize * 0.6,
            height: annotation.fontSize * 1.2
        )
        return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    private static func hitTestFreehand(points: [CGPoint], point: CGPoint, tolerance: CGFloat) -> Bool {
        guard points.count > 1 else { return false }

        for i in 0..<points.count - 1 {
            if hitTestLine(from: points[i], to: points[i + 1], point: point, tolerance: tolerance) {
                return true
            }
        }
        return false
    }

    private static func hitTestShape(annotation: Annotation, point: CGPoint, tolerance: CGFloat) -> Bool {
        let rect = AnnotationGeometry.boundingRect(for: annotation)
        let outerRect = rect.insetBy(dx: -tolerance, dy: -tolerance)
        let innerRect = rect.insetBy(dx: tolerance, dy: tolerance)
        return outerRect.contains(point) && (innerRect.isEmpty || !innerRect.contains(point))
    }
}
