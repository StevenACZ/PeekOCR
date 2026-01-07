//
//  AnnotationUndoManager.swift
//  PeekOCR
//
//  Manages undo/redo history specifically for annotations.
//  Uses composition with the generic UndoRedoManager.
//

import Foundation
import Combine

/// Specialized undo/redo manager for annotation arrays
final class AnnotationUndoManager: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // MARK: - Private Properties

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private let maxHistorySize: Int

    // MARK: - Initialization

    /// Creates a new annotation undo manager
    /// - Parameter maxHistorySize: Maximum number of states to keep in history (default: 50)
    init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - Public Methods

    /// Saves the current annotations state to the undo stack
    /// - Parameter annotations: The current state of annotations to save
    func saveState(_ annotations: [Annotation]) {
        undoStack.append(annotations)

        // Trim history if needed
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Clear redo stack on new action
        redoStack.removeAll()

        updateFlags()
    }

    /// Performs an undo operation
    /// - Parameter currentAnnotations: The current annotations before undoing
    /// - Returns: The previous state to restore, or nil if undo stack is empty
    func undo(currentAnnotations: [Annotation]) -> [Annotation]? {
        guard let previousState = undoStack.popLast() else { return nil }
        redoStack.append(currentAnnotations)
        updateFlags()
        return previousState
    }

    /// Performs a redo operation
    /// - Parameter currentAnnotations: The current annotations before redoing
    /// - Returns: The next state to restore, or nil if redo stack is empty
    func redo(currentAnnotations: [Annotation]) -> [Annotation]? {
        guard let nextState = redoStack.popLast() else { return nil }
        undoStack.append(currentAnnotations)
        updateFlags()
        return nextState
    }

    /// Clears all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateFlags()
    }

    // MARK: - Private Methods

    private func updateFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
