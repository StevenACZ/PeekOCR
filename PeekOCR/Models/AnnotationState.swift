//
//  AnnotationState.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI
import Combine

/// Available annotation tools
enum AnnotationTool: String, CaseIterable {
    case select
    case arrow
    case text
    case freehand
    case rectangle
    case oval

    /// SF Symbol name for the tool
    var iconName: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .freehand: return "pencil.line"
        case .rectangle: return "rectangle"
        case .oval: return "oval"
        }
    }

    /// Display name for the tool
    var displayName: String {
        switch self {
        case .select: return "Seleccionar"
        case .arrow: return "Flecha"
        case .text: return "Texto"
        case .freehand: return "Dibujo libre"
        case .rectangle: return "Rectangulo"
        case .oval: return "Ovalo"
        }
    }

    /// Keyboard shortcut (0-5)
    var shortcutKey: String {
        switch self {
        case .select: return "0"
        case .arrow: return "1"
        case .text: return "2"
        case .freehand: return "3"
        case .rectangle: return "4"
        case .oval: return "5"
        }
    }
}

/// Resize handles for selection
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}

/// Represents a single annotation on the canvas
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

/// Observable state for the annotation editor
final class AnnotationState: ObservableObject {
    // MARK: - Published Properties

    /// Currently selected tool
    @Published var selectedTool: AnnotationTool = .arrow

    /// Currently selected color
    @Published var selectedColor: Color = .red

    /// Current stroke width
    @Published var strokeWidth: CGFloat = 3.0

    /// All completed annotations
    @Published var annotations: [Annotation] = []

    /// Current annotation being drawn (in progress)
    @Published var currentAnnotation: Annotation?

    /// Undo stack for completed annotations
    @Published private(set) var undoStack: [[Annotation]] = []

    /// Redo stack for undone annotations
    @Published private(set) var redoStack: [[Annotation]] = []

    /// Whether text input is active
    @Published var isTextInputActive: Bool = false

    /// Position for text input overlay
    @Published var textInputPosition: CGPoint = .zero

    /// Current text being entered
    @Published var currentText: String = ""

    // MARK: - Selection Properties

    /// ID of currently selected annotation
    @Published var selectedAnnotationId: UUID?

    /// Active resize handle being dragged
    @Published var activeHandle: ResizeHandle?

    /// Starting point of drag operation
    @Published var dragStartPoint: CGPoint = .zero

    /// Original annotation state before drag
    private var originalAnnotation: Annotation?

    // MARK: - Computed Properties

    /// The currently selected annotation
    var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first { $0.id == id }
    }

    /// Whether undo is available
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether redo is available
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    // MARK: - Methods

    /// Start a new annotation at the given point
    func startAnnotation(at point: CGPoint) {
        var annotation = Annotation(
            tool: selectedTool,
            color: selectedColor,
            strokeWidth: strokeWidth,
            startPoint: point,
            endPoint: point
        )

        if selectedTool == .freehand {
            annotation.points = [point]
        }

        currentAnnotation = annotation
    }

    /// Update the current annotation as the user drags
    func updateAnnotation(to point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        annotation.endPoint = point

        if annotation.tool == .freehand {
            annotation.points.append(point)
        }

        currentAnnotation = annotation
    }

    /// Complete the current annotation
    func finishAnnotation() {
        guard let annotation = currentAnnotation else { return }

        // Save current state for undo
        undoStack.append(annotations)
        redoStack.removeAll()

        annotations.append(annotation)
        currentAnnotation = nil
    }

    /// Start text input at the given point
    func startTextInput(at point: CGPoint) {
        textInputPosition = point
        currentText = ""
        isTextInputActive = true
    }

    /// Complete text input and create text annotation
    func finishTextInput() {
        guard !currentText.isEmpty else {
            isTextInputActive = false
            return
        }

        // Save current state for undo
        undoStack.append(annotations)
        redoStack.removeAll()

        let textAnnotation = Annotation(
            tool: .text,
            color: selectedColor,
            strokeWidth: strokeWidth,
            startPoint: textInputPosition,
            text: currentText,
            fontSize: max(12, strokeWidth * 5)
        )

        annotations.append(textAnnotation)
        isTextInputActive = false
        currentText = ""
    }

    /// Cancel text input
    func cancelTextInput() {
        isTextInputActive = false
        currentText = ""
    }

    /// Undo the last annotation
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previousState
    }

    /// Redo the last undone annotation
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = nextState
    }

    /// Clear all annotations
    func clearAll() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.removeAll()
    }

    /// Reset state for a new editing session
    func reset() {
        annotations.removeAll()
        currentAnnotation = nil
        undoStack.removeAll()
        redoStack.removeAll()
        isTextInputActive = false
        currentText = ""
        selectedTool = .arrow
        selectedColor = .red
        strokeWidth = 3.0
        selectedAnnotationId = nil
        activeHandle = nil
    }

    // MARK: - Selection Methods

    /// Try to select an annotation at the given point
    func selectAnnotation(at point: CGPoint) -> Bool {
        // Check annotations in reverse order (top to bottom)
        for annotation in annotations.reversed() {
            if hitTest(annotation: annotation, at: point) {
                selectedAnnotationId = annotation.id
                return true
            }
        }
        selectedAnnotationId = nil
        return false
    }

    /// Deselect current annotation
    func deselectAnnotation() {
        selectedAnnotationId = nil
        activeHandle = nil
    }

    /// Delete the selected annotation
    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotationId else { return }
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.removeAll { $0.id == id }
        selectedAnnotationId = nil
    }

    /// Start moving or resizing the selected annotation
    func startDrag(at point: CGPoint, handle: ResizeHandle?) {
        guard let id = selectedAnnotationId,
              let annotation = annotations.first(where: { $0.id == id }) else { return }

        dragStartPoint = point
        activeHandle = handle
        originalAnnotation = annotation
    }

    /// Update the selected annotation during drag
    func updateDrag(to point: CGPoint) {
        guard let id = selectedAnnotationId,
              let original = originalAnnotation,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        var updated = original

        if let handle = activeHandle {
            // Resizing
            updated = resizeAnnotation(original, handle: handle, dx: dx, dy: dy)
        } else {
            // Moving
            updated = moveAnnotation(original, dx: dx, dy: dy)
        }

        annotations[index] = updated
    }

    /// Finish the drag operation
    func finishDrag() {
        if originalAnnotation != nil {
            // Save to undo stack only if we actually moved/resized
            if let id = selectedAnnotationId,
               let current = annotations.first(where: { $0.id == id }),
               let original = originalAnnotation,
               current.startPoint != original.startPoint || current.endPoint != original.endPoint {
                // Insert the original state into undo
                var previousState = annotations
                if let index = previousState.firstIndex(where: { $0.id == id }) {
                    previousState[index] = original
                }
                undoStack.append(previousState)
                redoStack.removeAll()
            }
        }
        originalAnnotation = nil
        activeHandle = nil
    }

    // MARK: - Hit Testing

    private func hitTest(annotation: Annotation, at point: CGPoint) -> Bool {
        let tolerance: CGFloat = 10

        switch annotation.tool {
        case .select:
            return false
        case .arrow:
            return hitTestLine(from: annotation.startPoint, to: annotation.endPoint, point: point, tolerance: tolerance)
        case .text:
            let textRect = CGRect(x: annotation.startPoint.x, y: annotation.startPoint.y,
                                  width: CGFloat(annotation.text.count) * annotation.fontSize * 0.6, height: annotation.fontSize * 1.2)
            return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .freehand:
            for i in 0..<annotation.points.count - 1 {
                if hitTestLine(from: annotation.points[i], to: annotation.points[i + 1], point: point, tolerance: tolerance) {
                    return true
                }
            }
            return false
        case .rectangle, .oval:
            let rect = boundingRect(for: annotation)
            let outerRect = rect.insetBy(dx: -tolerance, dy: -tolerance)
            let innerRect = rect.insetBy(dx: tolerance, dy: tolerance)
            return outerRect.contains(point) && (innerRect.isEmpty || !innerRect.contains(point))
        }
    }

    private func hitTestLine(from start: CGPoint, to end: CGPoint, point: CGPoint, tolerance: CGFloat) -> Bool {
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

    // MARK: - Geometry Helpers

    func boundingRect(for annotation: Annotation) -> CGRect {
        switch annotation.tool {
        case .select:
            return .zero
        case .arrow, .rectangle, .oval:
            return CGRect(
                x: min(annotation.startPoint.x, annotation.endPoint.x),
                y: min(annotation.startPoint.y, annotation.endPoint.y),
                width: abs(annotation.endPoint.x - annotation.startPoint.x),
                height: abs(annotation.endPoint.y - annotation.startPoint.y)
            )
        case .text:
            return CGRect(
                x: annotation.startPoint.x,
                y: annotation.startPoint.y,
                width: CGFloat(annotation.text.count) * annotation.fontSize * 0.6,
                height: annotation.fontSize * 1.2
            )
        case .freehand:
            guard !annotation.points.isEmpty else { return .zero }
            let minX = annotation.points.map(\.x).min() ?? 0
            let maxX = annotation.points.map(\.x).max() ?? 0
            let minY = annotation.points.map(\.y).min() ?? 0
            let maxY = annotation.points.map(\.y).max() ?? 0
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    func handleRect(for handle: ResizeHandle, in rect: CGRect) -> CGRect {
        let size: CGFloat = 10
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

    func hitTestHandle(at point: CGPoint) -> ResizeHandle? {
        guard let annotation = selectedAnnotation else { return nil }
        let rect = boundingRect(for: annotation)

        for handle in ResizeHandle.allCases {
            if handleRect(for: handle, in: rect).contains(point) {
                return handle
            }
        }
        return nil
    }

    // MARK: - Move and Resize

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
