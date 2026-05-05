// Live annotation overlay text editing lifecycle.

import AppKit

extension LiveAnnotationOverlayView {
    func beginTextInput(at pointInScreen: CGPoint) {
        guard let selectionRectInScreen, selectionRectInScreen.contains(pointInScreen) else { return }
        removeTextField(commit: true)
        pendingTextPoint = pointInScreen
        editingAnnotationID = nil
        showTextField(at: pointInScreen, initialText: "")
    }

    func beginTextInput(for annotation: LiveAnnotation) {
        removeTextField(commit: true)
        pendingTextPoint = annotation.startPoint
        editingAnnotationID = annotation.id
        selectedAnnotationID = annotation.id
        showTextField(at: annotation.startPoint, initialText: annotation.text)
    }

    func showTextField(at pointInScreen: CGPoint, initialText: String) {
        guard let window else { return }
        let pointInView = viewPoint(from: pointInScreen)
        let field = OverlayTextField(frame: CGRect(x: pointInView.x, y: pointInView.y, width: 240, height: 32))
        field.stringValue = initialText
        field.font = NSFont.systemFont(ofSize: CGFloat(appSettings.defaultAnnotationFontSize), weight: .bold)
        field.textColor = accentColor
        field.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        field.isBordered = true
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.onCommit = { [weak self] in
            self?.removeTextField(commit: true)
        }
        field.onCancel = { [weak self] in
            self?.removeTextField(commit: false)
        }
        addSubview(field)
        textField = field
        window.makeFirstResponder(field)
    }

    func removeTextField(commit: Bool) {
        defer {
            textField?.removeFromSuperview()
            textField = nil
            pendingTextPoint = nil
            editingAnnotationID = nil
            window?.makeFirstResponder(self)
            needsDisplay = true
        }

        guard commit, let textField, let point = pendingTextPoint else { return }
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let editingAnnotationID,
            let existing = annotations.first(where: { $0.id == editingAnnotationID })
        {
            recordAnnotationSnapshot()
            var updated = existing
            updated.text = text
            updated.startPoint = point
            updated.endPoint = point
            updateAnnotation(id: editingAnnotationID, with: updated)
            selectedAnnotationID = editingAnnotationID
            return
        }

        recordAnnotationSnapshot()
        let newAnnotation = LiveAnnotation(
            tool: .text,
            color: accentColor,
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

private final class OverlayTextField: NSTextField {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
    }

    override func insertNewline(_ sender: Any?) {
        onCommit?()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
