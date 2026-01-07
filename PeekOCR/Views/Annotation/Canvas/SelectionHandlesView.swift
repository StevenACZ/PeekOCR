//
//  SelectionHandlesView.swift
//  PeekOCR
//
//  Renders the selection border and eight resize handles around a selected annotation.
//

import SwiftUI

/// Helper for drawing selection handles on a GraphicsContext
enum SelectionHandlesRenderer {
    /// Draws selection border and resize handles for an annotation
    /// - Parameters:
    ///   - annotation: The selected annotation
    ///   - context: The graphics context to draw on
    ///   - boundingRect: Function to calculate bounding rect
    ///   - handleRect: Function to calculate handle rect
    static func draw(
        for annotation: Annotation,
        context: GraphicsContext,
        boundingRect: CGRect,
        handleRectProvider: (ResizeHandle, CGRect) -> CGRect
    ) {
        guard !boundingRect.isEmpty else { return }

        // Draw selection border (dashed)
        let borderPath = Path(boundingRect.insetBy(dx: -2, dy: -2))
        context.stroke(
            borderPath,
            with: .color(.blue.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )

        // Draw handles
        let handleColor = GraphicsContext.Shading.color(.blue)
        let handleBorderColor = GraphicsContext.Shading.color(.white)

        for handle in ResizeHandle.allCases {
            let handleRect = handleRectProvider(handle, boundingRect)

            // White border (slightly larger)
            let borderPath = Path(ellipseIn: handleRect.insetBy(dx: -1, dy: -1))
            context.fill(borderPath, with: handleBorderColor)

            // Blue fill
            let fillPath = Path(ellipseIn: handleRect)
            context.fill(fillPath, with: handleColor)
        }
    }
}
