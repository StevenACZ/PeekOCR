//
//  AnnotationState.swift
//  PeekOCR
//
//  Observable state manager for the annotation editor canvas.
//  Uses composition with specialized managers for undo/redo, drag, and text input.
//

import SwiftUI
import Combine

/// Main state manager for the annotation editor
final class AnnotationState: ObservableObject {
    // MARK: - Managers (Composition)

    let undoManager = AnnotationUndoManager()
    let dragManager = AnnotationDragManager()
    let textManager = AnnotationTextManager()

    // MARK: - Tool Properties

    @Published var selectedTool: AnnotationTool = .arrow {
        didSet {
            if textManager.isActive && oldValue == .text && selectedTool != .text {
                finishTextInput()
            }
        }
    }

    @Published var selectedColor: Color = .red
    @Published var strokeWidth: CGFloat = 3.0
    @Published var fontSize: CGFloat = 24.0

    // MARK: - Annotation Properties

    @Published var annotations: [Annotation] = []
    @Published var currentAnnotation: Annotation?

    // MARK: - Selection State

    @Published var selectedAnnotationId: UUID?

    var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first { $0.id == id }
    }

    // MARK: - Computed Properties (Delegated)

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }
    var isTextInputActive: Bool { textManager.isActive }
    var textInputPosition: CGPoint { textManager.position }
    var currentText: String {
        get { textManager.currentText }
        set { textManager.currentText = newValue }
    }
    var activeHandle: ResizeHandle? { dragManager.activeHandle }
    var dragStartPoint: CGPoint { dragManager.dragStartPoint }

    // MARK: - Initialization

    init() {
        let settings = AppSettings.shared
        self.strokeWidth = settings.defaultAnnotationStrokeWidth
        self.fontSize = settings.defaultAnnotationFontSize
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
        undoManager.saveState(annotations)
        annotations.append(annotation)
        currentAnnotation = nil
    }

    // MARK: - Text Input Methods

    func startTextInput(at point: CGPoint) {
        textManager.startInput(at: point)
    }

    func finishTextInput() {
        guard let annotation = textManager.createAnnotation(
            color: selectedColor,
            strokeWidth: strokeWidth,
            fontSize: fontSize
        ) else { return }

        undoManager.saveState(annotations)
        annotations.append(annotation)
    }

    func cancelTextInput() {
        textManager.cancel()
    }

    // MARK: - Undo/Redo Methods

    func undo() {
        guard let previousState = undoManager.undo(currentAnnotations: annotations) else { return }
        annotations = previousState
    }

    func redo() {
        guard let nextState = undoManager.redo(currentAnnotations: annotations) else { return }
        annotations = nextState
    }

    func clearAll() {
        guard !annotations.isEmpty else { return }
        undoManager.saveState(annotations)
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
        dragManager.reset()
    }

    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotationId else { return }
        undoManager.saveState(annotations)
        annotations.removeAll { $0.id == id }
        selectedAnnotationId = nil
    }

    // MARK: - Drag Methods

    func startDrag(at point: CGPoint, handle: ResizeHandle?) {
        guard let id = selectedAnnotationId,
              let annotation = annotations.first(where: { $0.id == id }) else { return }
        dragManager.startDrag(at: point, handle: handle, annotation: annotation)
    }

    func updateDrag(to point: CGPoint) {
        guard let id = selectedAnnotationId,
              let original = dragManager.getOriginalForUndo(),
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        annotations[index] = dragManager.calculateDragUpdate(to: point, for: original)
    }

    func finishDrag() {
        if let id = selectedAnnotationId,
           let current = annotations.first(where: { $0.id == id }),
           dragManager.hasChanges(current: current),
           let original = dragManager.getOriginalForUndo() {
            var previousState = annotations
            if let index = previousState.firstIndex(where: { $0.id == id }) {
                previousState[index] = original
            }
            undoManager.saveState(previousState)
        }
        dragManager.finishDrag()
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
        undoManager.clear()
        textManager.reset()
        dragManager.reset()
        selectedTool = .arrow
        selectedColor = .red
        strokeWidth = settings.defaultAnnotationStrokeWidth
        fontSize = settings.defaultAnnotationFontSize
        selectedAnnotationId = nil
    }
}
