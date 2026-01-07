//
//  Annotation.swift
//  PeekOCR
//
//  Represents a single annotation drawn on the canvas with tool type, color, and geometry.
//

import SwiftUI

/// Data model for a single annotation on the canvas
struct Annotation: Identifiable {
    let id = UUID()
    let tool: AnnotationTool
    let color: Color
    let strokeWidth: CGFloat

    /// Start point for shapes/arrows
    var startPoint: CGPoint

    /// End point for shapes/arrows
    var endPoint: CGPoint

    /// Points for freehand drawing
    var points: [CGPoint]

    /// Text content for text annotations
    var text: String

    /// Font size for text annotations
    var fontSize: CGFloat

    init(
        tool: AnnotationTool,
        color: Color,
        strokeWidth: CGFloat,
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        points: [CGPoint] = [],
        text: String = "",
        fontSize: CGFloat = 16
    ) {
        self.tool = tool
        self.color = color
        self.strokeWidth = strokeWidth
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.points = points
        self.text = text
        self.fontSize = fontSize
    }
}
