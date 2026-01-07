//
//  AnnotationTextManager.swift
//  PeekOCR
//
//  Manages text input state for text annotations.
//

import SwiftUI
import Combine

/// Manages text input operations for creating text annotations
final class AnnotationTextManager: ObservableObject {
    // MARK: - Published Properties

    @Published var isActive: Bool = false
    @Published var position: CGPoint = .zero
    @Published var currentText: String = ""

    // MARK: - Public Methods

    /// Starts text input at the specified position
    /// - Parameter point: The position where text input should appear
    func startInput(at point: CGPoint) {
        position = point
        currentText = ""
        isActive = true
    }

    /// Creates a text annotation from the current input
    /// - Parameters:
    ///   - color: The color for the text annotation
    ///   - strokeWidth: The stroke width for the annotation
    ///   - fontSize: The font size for the text
    /// - Returns: The created annotation, or nil if text is empty
    func createAnnotation(color: Color, strokeWidth: CGFloat, fontSize: CGFloat) -> Annotation? {
        guard !currentText.isEmpty else {
            isActive = false
            return nil
        }

        let annotation = Annotation(
            tool: .text,
            color: color,
            strokeWidth: strokeWidth,
            startPoint: position,
            text: currentText,
            fontSize: fontSize
        )

        isActive = false
        currentText = ""

        return annotation
    }

    /// Finishes text input and returns whether there was content
    /// - Returns: True if there was text content, false otherwise
    func finish() -> Bool {
        let hadContent = !currentText.isEmpty
        isActive = false
        currentText = ""
        return hadContent
    }

    /// Cancels the current text input
    func cancel() {
        isActive = false
        currentText = ""
    }

    /// Resets all text input state
    func reset() {
        isActive = false
        position = .zero
        currentText = ""
    }
}
