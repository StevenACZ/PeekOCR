//
//  AnnotationGeometry.swift
//  PeekOCR
//
//  Shared geometry calculations for image rect and shape bounds.
//

import Foundation
import CoreGraphics

/// Utility functions for annotation geometry calculations
enum AnnotationGeometry {
    // MARK: - Bounding Rect

    /// Calculates the bounding rectangle for an annotation
    /// - Parameter annotation: The annotation to calculate bounds for
    /// - Returns: The bounding rectangle
    static func boundingRect(for annotation: Annotation) -> CGRect {
        switch annotation.tool {
        case .select:
            return .zero
        case .arrow, .rectangle, .oval:
            return shapeRect(from: annotation.startPoint, to: annotation.endPoint)
        case .text:
            return textRect(for: annotation)
        case .freehand:
            return freehandRect(for: annotation.points)
        }
    }

    /// Calculates rectangle from two points (normalized min/max)
    /// - Parameters:
    ///   - start: First point
    ///   - end: Second point
    /// - Returns: Normalized rectangle
    static func shapeRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    // MARK: - Image Rect (Aspect Fit)

    /// Calculates the image rect with aspect fit within a canvas
    /// - Parameters:
    ///   - imageSize: Original image size
    ///   - canvasSize: Canvas size to fit into
    /// - Returns: The fitted image rectangle
    static func calculateImageRect(imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect = canvasSize.width / canvasSize.height

        var drawRect: CGRect

        if imageAspect > canvasAspect {
            // Image is wider - fit to width
            let drawWidth = canvasSize.width
            let drawHeight = drawWidth / imageAspect
            let drawY = (canvasSize.height - drawHeight) / 2
            drawRect = CGRect(x: 0, y: drawY, width: drawWidth, height: drawHeight)
        } else {
            // Image is taller - fit to height
            let drawHeight = canvasSize.height
            let drawWidth = drawHeight * imageAspect
            let drawX = (canvasSize.width - drawWidth) / 2
            drawRect = CGRect(x: drawX, y: 0, width: drawWidth, height: drawHeight)
        }

        return drawRect
    }

    /// Calculates scale factors between image and display rect
    /// - Parameters:
    ///   - imageSize: Original image size
    ///   - rect: Display rectangle
    /// - Returns: Scale factors (scaleX, scaleY)
    static func imageRectScale(imageSize: CGSize, rect: CGRect) -> (scaleX: CGFloat, scaleY: CGFloat) {
        let scaleX = imageSize.width / rect.width
        let scaleY = imageSize.height / rect.height
        return (scaleX, scaleY)
    }

    // MARK: - Handle Rects

    /// Calculates the rectangle for a resize handle
    /// - Parameters:
    ///   - handle: The handle position
    ///   - rect: The bounding rectangle
    ///   - size: Handle size (default: 10)
    /// - Returns: The handle rectangle
    static func handleRect(for handle: ResizeHandle, in rect: CGRect, size: CGFloat = 10) -> CGRect {
        let halfSize = size / 2

        switch handle {
        case .topLeft:
            return CGRect(x: rect.minX - halfSize, y: rect.minY - halfSize, width: size, height: size)
        case .top:
            return CGRect(x: rect.midX - halfSize, y: rect.minY - halfSize, width: size, height: size)
        case .topRight:
            return CGRect(x: rect.maxX - halfSize, y: rect.minY - halfSize, width: size, height: size)
        case .left:
            return CGRect(x: rect.minX - halfSize, y: rect.midY - halfSize, width: size, height: size)
        case .right:
            return CGRect(x: rect.maxX - halfSize, y: rect.midY - halfSize, width: size, height: size)
        case .bottomLeft:
            return CGRect(x: rect.minX - halfSize, y: rect.maxY - halfSize, width: size, height: size)
        case .bottom:
            return CGRect(x: rect.midX - halfSize, y: rect.maxY - halfSize, width: size, height: size)
        case .bottomRight:
            return CGRect(x: rect.maxX - halfSize, y: rect.maxY - halfSize, width: size, height: size)
        }
    }

    // MARK: - Private Helpers

    private static func textRect(for annotation: Annotation) -> CGRect {
        CGRect(
            x: annotation.startPoint.x,
            y: annotation.startPoint.y,
            width: CGFloat(annotation.text.count) * annotation.fontSize * 0.6,
            height: annotation.fontSize * 1.2
        )
    }

    private static func freehandRect(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
