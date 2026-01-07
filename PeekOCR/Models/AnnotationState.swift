//
//  AnnotationState.swift
//  PeekOCR
//
//  Observable state manager for the annotation editor canvas.
//

import SwiftUI
import Combine

/// Main state manager for the annotation editor
final class AnnotationState: ObservableObject {
    // MARK: - Tool Properties

    /// Currently selected tool
    @Published var selectedTool: AnnotationTool = .arrow {
        didSet {
            // Close text input when switching away from text tool
            if isTextInputActive && oldValue == .text && selectedTool != .text {
                finishTextInput()
            }
        }
    }

    /// Currently selected color
    @Published var selectedColor: Color = .red

    /// Current stroke width (initialized from AppSettings)
    @Published var strokeWidth: CGFloat = 3.0

    /// Current font size (initialized from AppSettings)
    @Published var fontSize: CGFloat = 24.0

    // MARK: - Initialization

    init() {
        let settings = AppSettings.shared
        self.strokeWidth = settings.defaultAnnotationStrokeWidth
        self.fontSize = settings.defaultAnnotationFontSize
    }

    // MARK: - Annotation Properties

    /// All completed annotations
    @Published var annotations: [Annotation] = []

    /// Current annotation being drawn (in progress)
    @Published var currentAnnotation: Annotation?

    // MARK: - History (Undo/Redo)

    @Published private(set) var undoStack: [[Annotation]] = []
    @Published private(set) var redoStack: [[Annotation]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Text Input State

    @Published var isTextInputActive: Bool = false
    @Published var textInputPosition: CGPoint = .zero
    @Published var currentText: String = ""

    // MARK: - Selection State

    @Published var selectedAnnotationId: UUID?
    @Published var activeHandle: ResizeHandle?
    @Published var dragStartPoint: CGPoint = .zero
    private var originalAnnotation: Annotation?

    var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first { $0.id == id }
    }

    // MARK: - Drawing Methods

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

    func updateAnnotation(to point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        annotation.endPoint = point

        if annotation.tool == .freehand {
            annotation.points.append(point)
        }

        currentAnnotation = annotation
    }

    func finishAnnotation() {
        guard let annotation = currentAnnotation else { return }

        saveToUndoStack()
        annotations.append(annotation)
        currentAnnotation = nil
    }

    // MARK: - Text Input Methods

    func startTextInput(at point: CGPoint) {
        textInputPosition = point
        currentText = ""
        isTextInputActive = true
    }

    func finishTextInput() {
        guard !currentText.isEmpty else {
            isTextInputActive = false
            return
        }

        saveToUndoStack()

        let textAnnotation = Annotation(
            tool: .text,
            color: selectedColor,
            strokeWidth: strokeWidth,
            startPoint: textInputPosition,
            text: currentText,
            fontSize: fontSize
        )

        annotations.append(textAnnotation)
        isTextInputActive = false
        currentText = ""
    }

    func cancelTextInput() {
        isTextInputActive = false
        currentText = ""
    }

    // MARK: - Undo/Redo Methods

    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previousState
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = nextState
    }

    func clearAll() {
        guard !annotations.isEmpty else { return }
        saveToUndoStack()
        annotations.removeAll()
    }

    // MARK: - Selection Methods

    func selectAnnotation(at point: CGPoint) -> Bool {
        for annotation in annotations.reversed() {
            if HitTestEngine.hitTest(annotation: annotation, at: point) {
                selectedAnnotationId = annotation.id
                return true
            }
        }
        selectedAnnotationId = nil
        return false
    }

    func deselectAnnotation() {
        selectedAnnotationId = nil
        activeHandle = nil
    }

    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotationId else { return }
        saveToUndoStack()
        annotations.removeAll { $0.id == id }
        selectedAnnotationId = nil
    }

    // MARK: - Drag Methods

    func startDrag(at point: CGPoint, handle: ResizeHandle?) {
        guard let id = selectedAnnotationId,
              let annotation = annotations.first(where: { $0.id == id }) else { return }

        dragStartPoint = point
        activeHandle = handle
        originalAnnotation = annotation
    }

    func updateDrag(to point: CGPoint) {
        guard let id = selectedAnnotationId,
              let original = originalAnnotation,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        let updated: Annotation
        if let handle = activeHandle {
            updated = AnnotationTransformer.resize(original, handle: handle, dx: dx, dy: dy)
        } else {
            updated = AnnotationTransformer.move(original, dx: dx, dy: dy)
        }

        annotations[index] = updated
    }

    func finishDrag() {
        if let id = selectedAnnotationId,
           let current = annotations.first(where: { $0.id == id }),
           let original = originalAnnotation,
           current.startPoint != original.startPoint || current.endPoint != original.endPoint {
            var previousState = annotations
            if let index = previousState.firstIndex(where: { $0.id == id }) {
                previousState[index] = original
            }
            undoStack.append(previousState)
            redoStack.removeAll()
        }
        originalAnnotation = nil
        activeHandle = nil
    }

    // MARK: - Geometry Helpers (Delegated)

    func boundingRect(for annotation: Annotation) -> CGRect {
        AnnotationGeometry.boundingRect(for: annotation)
    }

    func handleRect(for handle: ResizeHandle, in rect: CGRect) -> CGRect {
        AnnotationGeometry.handleRect(for: handle, in: rect)
    }

    func hitTestHandle(at point: CGPoint) -> ResizeHandle? {
        guard let annotation = selectedAnnotation else { return nil }
        return HitTestEngine.hitTestHandle(at: point, for: annotation)
    }

    // MARK: - Reset

    func reset() {
        let settings = AppSettings.shared
        annotations.removeAll()
        currentAnnotation = nil
        undoStack.removeAll()
        redoStack.removeAll()
        isTextInputActive = false
        currentText = ""
        selectedTool = .arrow
        selectedColor = .red
        strokeWidth = settings.defaultAnnotationStrokeWidth
        fontSize = settings.defaultAnnotationFontSize
        selectedAnnotationId = nil
        activeHandle = nil
    }

    // MARK: - Private Helpers

    private func saveToUndoStack() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }
}
