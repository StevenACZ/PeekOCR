//
//  UndoRedoManager.swift
//  PeekOCR
//
//  Generic undo/redo manager using stack-based history. Reusable across the app.
//

import Foundation
import Combine

/// Generic manager for undo/redo operations with configurable history limit
final class UndoRedoManager<T>: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // MARK: - Private Properties

    private var undoStack: [T] = []
    private var redoStack: [T] = []
    private let maxHistorySize: Int

    // MARK: - Initialization

    /// Creates a new history manager
    /// - Parameter maxHistorySize: Maximum number of states to keep in history (default: 50)
    init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - Public Methods

    /// Saves a state to the undo stack
    /// - Parameter state: The state to save
    func saveState(_ state: T) {
        undoStack.append(state)

        // Trim history if needed
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Clear redo stack on new action
        redoStack.removeAll()

        updateFlags()
    }

    /// Undoes the last action and returns the previous state
    /// - Returns: The previous state, or nil if undo stack is empty
    func undo() -> T? {
        guard let previousState = undoStack.popLast() else { return nil }
        updateFlags()
        return previousState
    }

    /// Saves state to redo stack (call after undo with current state)
    /// - Parameter currentState: The current state before reverting
    func pushToRedo(_ currentState: T) {
        redoStack.append(currentState)
        updateFlags()
    }

    /// Redoes the last undone action
    /// - Returns: The next state, or nil if redo stack is empty
    func redo() -> T? {
        guard let nextState = redoStack.popLast() else { return nil }
        updateFlags()
        return nextState
    }

    /// Saves state to undo stack (call after redo with current state)
    /// - Parameter currentState: The current state before redoing
    func pushToUndo(_ currentState: T) {
        undoStack.append(currentState)
        updateFlags()
    }

    /// Clears all history
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
