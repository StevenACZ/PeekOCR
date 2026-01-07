//
//  TextInputController.swift
//  PeekOCR
//
//  State machine for text annotation input lifecycle (start -> edit -> finish/cancel).
//

import SwiftUI
import Combine

/// Manages text input state for text annotations
final class TextInputController: ObservableObject {
    // MARK: - Published Properties

    /// Whether text input is currently active
    @Published var isActive: Bool = false

    /// Position for the text input overlay
    @Published var position: CGPoint = .zero

    /// Current text being entered
    @Published var currentText: String = ""

    // MARK: - Computed Properties

    /// Whether the current text is empty or whitespace-only
    var isEmpty: Bool {
        currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Public Methods

    /// Starts text input at the specified position
    /// - Parameter point: The position for the text input
    func start(at point: CGPoint) {
        position = point
        currentText = ""
        isActive = true
    }

    /// Finishes text input and creates a text annotation
    /// - Parameters:
    ///   - color: The color for the text annotation
    ///   - strokeWidth: Used to calculate font size
    /// - Returns: The created annotation, or nil if text was empty
    func finish(color: Color, strokeWidth: CGFloat) -> Annotation? {
        guard !isEmpty else {
            cancel()
            return nil
        }

        let annotation = Annotation(
            tool: .text,
            color: color,
            strokeWidth: strokeWidth,
            startPoint: position,
            text: currentText,
            fontSize: max(12, strokeWidth * 5)
        )

        reset()
        return annotation
    }

    /// Cancels text input without creating an annotation
    func cancel() {
        reset()
    }

    // MARK: - Private Methods

    private func reset() {
        isActive = false
        currentText = ""
        position = .zero
    }
}
