//
//  AnnotationDragManager.swift
//  PeekOCR
//
//  Manages drag and resize state for annotations.
//

import SwiftUI
import Combine

/// Manages drag operations for moving and resizing annotations
final class AnnotationDragManager: ObservableObject {
    // MARK: - Published Properties

    @Published var dragStartPoint: CGPoint = .zero
    @Published var activeHandle: ResizeHandle?

    // MARK: - Private Properties

    private(set) var originalAnnotation: Annotation?
    private(set) var isDragging: Bool = false

    // MARK: - Public Methods

    /// Starts a drag operation
    /// - Parameters:
    ///   - point: The starting point of the drag
    ///   - handle: The resize handle being dragged (nil for move operation)
    ///   - annotation: The annotation being dragged
    func startDrag(at point: CGPoint, handle: ResizeHandle?, annotation: Annotation) {
        dragStartPoint = point
        activeHandle = handle
        originalAnnotation = annotation
        isDragging = true
    }

    /// Calculates the updated annotation based on drag movement
    /// - Parameters:
    ///   - point: The current drag point
    ///   - original: The original annotation state
    /// - Returns: The transformed annotation
    func calculateDragUpdate(to point: CGPoint, for original: Annotation) -> Annotation {
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        if let handle = activeHandle {
            return AnnotationTransformer.resize(original, handle: handle, dx: dx, dy: dy)
        } else {
            return AnnotationTransformer.move(original, dx: dx, dy: dy)
        }
    }

    /// Checks if the annotation has been modified during drag
    /// - Parameter current: The current state of the annotation
    /// - Returns: True if the annotation was moved or resized
    func hasChanges(current: Annotation) -> Bool {
        guard let original = originalAnnotation else { return false }
        return current.startPoint != original.startPoint
            || current.endPoint != original.endPoint
            || current.points != original.points
            || current.fontSize != original.fontSize
            || current.text != original.text
    }

    /// Gets the original annotation for undo purposes
    /// - Returns: The original annotation before drag started
    func getOriginalForUndo() -> Annotation? {
        return originalAnnotation
    }

    /// Ends the current drag operation
    func finishDrag() {
        originalAnnotation = nil
        activeHandle = nil
        isDragging = false
    }

    /// Resets all drag state
    func reset() {
        dragStartPoint = .zero
        activeHandle = nil
        originalAnnotation = nil
        isDragging = false
    }
}
