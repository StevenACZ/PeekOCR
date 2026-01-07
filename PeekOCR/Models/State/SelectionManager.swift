//
//  SelectionManager.swift
//  PeekOCR
//
//  Manages annotation selection, dragging, and resizing operations.
//

import SwiftUI
import Combine

/// Manages selection state and drag/resize operations for annotations
final class SelectionManager: ObservableObject {
    // MARK: - Published Properties

    /// ID of currently selected annotation
    @Published var selectedAnnotationId: UUID?

    /// Active resize handle being dragged
    @Published var activeHandle: ResizeHandle?

    /// Starting point of drag operation
    @Published private(set) var dragStartPoint: CGPoint = .zero

    /// Whether a drag operation is in progress
    @Published private(set) var isDragging: Bool = false

    // MARK: - Private Properties

    private var originalAnnotation: Annotation?

    // MARK: - Computed Properties

    /// Whether an annotation is currently selected
    var hasSelection: Bool {
        selectedAnnotationId != nil
    }

    // MARK: - Selection Methods

    /// Selects an annotation by ID
    /// - Parameter id: The annotation ID to select
    func select(_ id: UUID) {
        selectedAnnotationId = id
    }

    /// Deselects the current annotation
    func deselect() {
        selectedAnnotationId = nil
        activeHandle = nil
        originalAnnotation = nil
        isDragging = false
    }

    // MARK: - Drag Methods

    /// Starts a drag/resize operation
    /// - Parameters:
    ///   - point: Starting point of the drag
    ///   - handle: Optional resize handle being dragged
    ///   - annotation: The annotation being modified
    func startDrag(at point: CGPoint, handle: ResizeHandle?, annotation: Annotation) {
        dragStartPoint = point
        activeHandle = handle
        originalAnnotation = annotation
        isDragging = true
    }

    /// Calculates the updated annotation during drag
    /// - Parameter currentPoint: Current drag position
    /// - Returns: Updated annotation, or nil if no drag in progress
    func calculateDragUpdate(to currentPoint: CGPoint) -> Annotation? {
        guard let original = originalAnnotation else { return nil }

        let dx = currentPoint.x - dragStartPoint.x
        let dy = currentPoint.y - dragStartPoint.y

        if let handle = activeHandle {
            return resizeAnnotation(original, handle: handle, dx: dx, dy: dy)
        } else {
            return moveAnnotation(original, dx: dx, dy: dy)
        }
    }

    /// Returns the original annotation state (for undo)
    func getOriginalAnnotation() -> Annotation? {
        return originalAnnotation
    }

    /// Finishes the drag operation
    /// - Returns: Whether the annotation was actually modified
    func finishDrag() -> Bool {
        let wasModified = originalAnnotation != nil && isDragging
        originalAnnotation = nil
        activeHandle = nil
        isDragging = false
        return wasModified
    }

    // MARK: - Private Transform Methods

    private func moveAnnotation(_ annotation: Annotation, dx: CGFloat, dy: CGFloat) -> Annotation {
        var moved = annotation
        moved.startPoint = CGPoint(x: annotation.startPoint.x + dx, y: annotation.startPoint.y + dy)
        moved.endPoint = CGPoint(x: annotation.endPoint.x + dx, y: annotation.endPoint.y + dy)

        if annotation.tool == .freehand {
            moved.points = annotation.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        }

        return moved
    }

    private func resizeAnnotation(_ annotation: Annotation, handle: ResizeHandle, dx: CGFloat, dy: CGFloat) -> Annotation {
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
}
