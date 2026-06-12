// Live annotation overlay text editing lifecycle.

import AppKit

extension LiveAnnotationOverlayView {
    var isEditingText: Bool { textEditor != nil }

    func beginTextInput(at pointInScreen: CGPoint) {
        guard let selectionRectInScreen, selectionRectInScreen.contains(pointInScreen) else { return }
        dismissTextEditor(commit: true)
        pendingTextPoint = pointInScreen
        editingAnnotationID = nil
        showTextEditor(initialText: "", fontSize: CGFloat(appSettings.defaultAnnotationFontSize))
    }

    func beginTextInput(for annotation: LiveAnnotation) {
        dismissTextEditor(commit: true)
        pendingTextPoint = annotation.startPoint
        editingAnnotationID = annotation.id
        selectedAnnotationID = annotation.id
        showTextEditor(initialText: annotation.text, fontSize: annotation.fontSize)
    }

    private func showTextEditor(initialText: String, fontSize: CGFloat) {
        guard let window else { return }

        let editor = OverlayTextEditorView(initialText: initialText, fontSize: fontSize, color: textColor)
        editor.onCommit = { [weak self] in self?.dismissTextEditor(commit: true) }
        editor.onCancel = { [weak self] in self?.dismissTextEditor(commit: false) }
        editor.onTextChange = { [weak self] in self?.layoutTextEditor() }
        addSubview(editor)
        textEditor = editor
        layoutTextEditor()
        editor.focus(in: window)
        needsDisplay = true
    }

    /// Keeps the editor glued to the annotation anchor: `pendingTextPoint` is the
    /// text's top-left corner, so the typed text sits exactly where the
    /// annotation will render.
    func layoutTextEditor() {
        guard let textEditor, let point = pendingTextPoint else { return }
        textEditor.frame = textEditor.frame(anchoredAtTextTopLeft: viewPoint(from: point))
    }

    func dismissTextEditor(commit: Bool) {
        defer {
            textEditor?.removeFromSuperview()
            textEditor = nil
            pendingTextPoint = nil
            editingAnnotationID = nil
            window?.makeFirstResponder(self)
            needsDisplay = true
        }

        guard commit, let textEditor, let point = pendingTextPoint else { return }
        let text = textEditor.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingAnnotationID,
            let existing = annotations.first(where: { $0.id == editingAnnotationID })
        {
            if text.isEmpty {
                // Committing an emptied annotation deletes it (undoable).
                deleteAnnotation(id: editingAnnotationID)
            } else if existing.text != text {
                pushUndoSnapshot(annotations)
                var updated = existing
                updated.text = text
                updated.startPoint = point
                updated.endPoint = point
                updateAnnotation(id: editingAnnotationID, with: updated)
                selectedAnnotationID = editingAnnotationID
            }
            return
        }

        guard !text.isEmpty else { return }

        pushUndoSnapshot(annotations)
        let newAnnotation = LiveAnnotation(
            tool: .text,
            color: textColor,
            startPoint: point,
            endPoint: point,
            text: text,
            fontSize: CGFloat(appSettings.defaultAnnotationFontSize),
            strokeWidth: CGFloat(appSettings.defaultAnnotationStrokeWidth)
        )
        annotations.append(newAnnotation)
        selectedAnnotationID = newAnnotation.id
    }
}
