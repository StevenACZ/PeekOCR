//
//  AnnotationTransformer.swift
//  PeekOCR
//
//  Pure functions to move and resize annotations.
//

import Foundation
import CoreGraphics

/// Pure transformation functions for annotations
enum AnnotationTransformer {
    // MARK: - Move

    /// Moves an annotation by the specified delta
    /// - Parameters:
    ///   - annotation: The annotation to move
    ///   - dx: Horizontal delta
    ///   - dy: Vertical delta
    /// - Returns: The moved annotation
    static func move(_ annotation: Annotation, dx: CGFloat, dy: CGFloat) -> Annotation {
        var moved = annotation
        moved.startPoint = CGPoint(x: annotation.startPoint.x + dx, y: annotation.startPoint.y + dy)
        moved.endPoint = CGPoint(x: annotation.endPoint.x + dx, y: annotation.endPoint.y + dy)

        if annotation.tool == .freehand {
            moved.points = annotation.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        }

        return moved
    }

    // MARK: - Resize

    /// Resizes an annotation by dragging a handle
    /// - Parameters:
    ///   - annotation: The annotation to resize
    ///   - handle: The handle being dragged
    ///   - dx: Horizontal delta
    ///   - dy: Vertical delta
    /// - Returns: The resized annotation
    static func resize(_ annotation: Annotation, handle: ResizeHandle, dx: CGFloat, dy: CGFloat) -> Annotation {
        // Special case for text: resize by changing fontSize
        if annotation.tool == .text {
            return resizeText(annotation, handle: handle, dx: dx, dy: dy)
        }

        var resized = annotation

        switch handle {
        case .topLeft:
            resized.startPoint = CGPoint(x: annotation.startPoint.x + dx, y: annotation.startPoint.y + dy)
        case .top:
            resized.startPoint = CGPoint(x: annotation.startPoint.x, y: annotation.startPoint.y + dy)
        case .topRight:
            resized.startPoint = CGPoint(x: annotation.startPoint.x, y: annotation.startPoint.y + dy)
            resized.endPoint = CGPoint(x: annotation.endPoint.x + dx, y: annotation.endPoint.y)
        case .left:
            resized.startPoint = CGPoint(x: annotation.startPoint.x + dx, y: annotation.startPoint.y)
        case .right:
            resized.endPoint = CGPoint(x: annotation.endPoint.x + dx, y: annotation.endPoint.y)
        case .bottomLeft:
            resized.startPoint = CGPoint(x: annotation.startPoint.x + dx, y: annotation.startPoint.y)
            resized.endPoint = CGPoint(x: annotation.endPoint.x, y: annotation.endPoint.y + dy)
        case .bottom:
            resized.endPoint = CGPoint(x: annotation.endPoint.x, y: annotation.endPoint.y + dy)
        case .bottomRight:
            resized.endPoint = CGPoint(x: annotation.endPoint.x + dx, y: annotation.endPoint.y + dy)
        }

        return resized
    }

    /// Resizes a text annotation by changing its fontSize
    private static func resizeText(_ annotation: Annotation, handle: ResizeHandle, dx: CGFloat, dy: CGFloat) -> Annotation {
        var resized = annotation
        let currentHeight = annotation.fontSize * 1.2
        var newHeight = currentHeight

        switch handle {
        case .topLeft, .top, .topRight:
            // Dragging from top - increase size when moving up (negative dy)
            newHeight = currentHeight - dy
            // Adjust startPoint to maintain bottom position
            resized.startPoint.y = annotation.startPoint.y + dy
        case .bottomLeft, .bottom, .bottomRight:
            // Dragging from bottom - increase size when moving down (positive dy)
            newHeight = currentHeight + dy
        case .left, .right:
            // Horizontal handles don't resize text
            return annotation
        }

        // Convert height to fontSize with constraints (8-72pt)
        let newFontSize = max(8, min(72, newHeight / 1.2))
        resized.fontSize = newFontSize

        return resized
    }

    // MARK: - Scale

    /// Scales an annotation by a factor around its center
    /// - Parameters:
    ///   - annotation: The annotation to scale
    ///   - scale: Scale factor
    /// - Returns: The scaled annotation
    static func scale(_ annotation: Annotation, by scale: CGFloat) -> Annotation {
        let rect = AnnotationGeometry.boundingRect(for: annotation)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var scaled = annotation

        func scalePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: center.x + (point.x - center.x) * scale,
                y: center.y + (point.y - center.y) * scale
            )
        }

        scaled.startPoint = scalePoint(annotation.startPoint)
        scaled.endPoint = scalePoint(annotation.endPoint)

        if annotation.tool == .freehand {
            scaled.points = annotation.points.map { scalePoint($0) }
        }

        return scaled
    }
}
