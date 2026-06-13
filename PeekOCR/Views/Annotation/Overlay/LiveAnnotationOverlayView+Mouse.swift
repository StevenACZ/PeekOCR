// Live annotation overlay mouse interaction handling.

import AppKit

extension LiveAnnotationOverlayView {
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let pointInScreen = screenPoint(from: event.locationInWindow, window: window)

        if mode == .quickSelect {
            notifyActivationIfNeeded()
            let origin = clamp(pointInScreen, to: overlayScreen.frame)
            selectionRectInScreen = CGRect(origin: origin, size: .zero)
            interaction = .creatingSelection(origin: origin)
            return
        }

        if isEditingText {
            if handleToolbarClick(at: pointInScreen) {
                dismissTextEditor(commit: true)
                return
            }

            dismissTextEditor(commit: true)
            return
        }

        if handleToolbarClick(at: pointInScreen) {
            return
        }

        dismissTextEditor(commit: true)

        if let annotationID = selectedAnnotationID,
            let annotation = annotations.first(where: { $0.id == annotationID }),
            let handle = hitTestAnnotationResizeHandle(for: annotation, at: pointInScreen)
        {
            notifyActivationIfNeeded()
            beginAnnotationTransaction()
            interaction = .resizingAnnotation(id: annotationID, handle: handle, initialAnnotation: annotation)
            return
        }

        if let selectionRectInScreen,
            let handle = hitTestHandle(at: pointInScreen, selectionRectInScreen: selectionRectInScreen)
        {
            notifyActivationIfNeeded()
            selectedAnnotationID = nil
            beginAnnotationTransaction()
            interaction = .resizingSelection(handle: handle, initialRect: selectionRectInScreen, initialAnnotations: annotations)
            return
        }

        if let selectionRectInScreen, selectionRectInScreen.contains(pointInScreen) {
            if let annotationID = hitTestAnnotation(at: pointInScreen),
                let annotation = annotations.first(where: { $0.id == annotationID })
            {
                notifyActivationIfNeeded()
                selectedAnnotationID = annotationID

                if annotation.tool == .text && event.clickCount >= 2 {
                    beginTextInput(for: annotation)
                    return
                }

                beginAnnotationTransaction()
                interaction = .movingAnnotation(id: annotationID, origin: pointInScreen, initialAnnotation: annotation)
                return
            } else {
                if selectedAnnotationID != nil {
                    selectedAnnotationID = nil
                    interaction = .none
                    needsDisplay = true
                    return
                }
                selectedAnnotationID = nil
            }

            switch selectedTool {
            case .select:
                notifyActivationIfNeeded()
                beginAnnotationTransaction()
                interaction = .movingSelection(origin: pointInScreen, initialRect: selectionRectInScreen, initialAnnotations: annotations)
            case .text:
                notifyActivationIfNeeded()
                beginTextInput(at: pointInScreen)
            case .arrow, .highlight, .pen:
                notifyActivationIfNeeded()
                var annotation = LiveAnnotation(
                    tool: selectedTool,
                    color: selectedTool == .highlight ? annotationColor : accentColor,
                    startPoint: pointInScreen,
                    endPoint: pointInScreen,
                    text: "",
                    fontSize: CGFloat(appSettings.defaultAnnotationFontSize),
                    strokeWidth: selectedTool == .pen
                        ? CGFloat(appSettings.defaultPenStrokeWidth)
                        : CGFloat(appSettings.defaultAnnotationStrokeWidth)
                )
                if selectedTool == .pen {
                    annotation.points = [pointInScreen]
                }
                interaction = .drawingAnnotation(annotation: annotation)
            }
            return
        }

        let screen = overlayScreen
        notifyActivationIfNeeded()
        selectedAnnotationID = nil
        selectionRectInScreen = CGRect(origin: clamp(pointInScreen, to: screen.frame), size: .zero)
        annotations = []
        annotationHistory = []
        annotationRedoStack = []
        pendingUndoSnapshot = nil
        selectedTool = .select
        interaction = .creatingSelection(origin: clamp(pointInScreen, to: screen.frame))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let pointInScreen = screenPoint(from: event.locationInWindow, window: window)

        switch interaction {
        case .none:
            break
        case .creatingSelection(let origin):
            let screen = overlayScreen
            selectionRectInScreen = normalizedRect(from: origin, to: clamp(pointInScreen, to: screen.frame))
        case .movingSelection(let origin, let initialRect, let initialAnnotations):
            let delta = CGPoint(x: pointInScreen.x - origin.x, y: pointInScreen.y - origin.y)
            let moved = initialRect.offsetBy(dx: delta.x, dy: delta.y)
            let clampedRect = clamp(rect: moved, to: overlayScreen.frame)
            selectionRectInScreen = clampedRect
            annotations = translated(initialAnnotations, dx: clampedRect.minX - initialRect.minX, dy: clampedRect.minY - initialRect.minY)
        case .resizingSelection(let handle, let initialRect, let initialAnnotations):
            let screen = overlayScreen
            let resizedRect = resize(initialRect: initialRect, handle: handle, point: clamp(pointInScreen, to: screen.frame))
            selectionRectInScreen = resizedRect
            annotations = transformed(initialAnnotations, from: initialRect, to: resizedRect)
        case .movingAnnotation(let id, let origin, let initialAnnotation):
            let delta = CGPoint(x: pointInScreen.x - origin.x, y: pointInScreen.y - origin.y)
            let movedAnnotation = translated(annotation: initialAnnotation, dx: delta.x, dy: delta.y)
            updateAnnotation(id: id, with: movedAnnotation)
        case .resizingAnnotation(let id, let handle, let initialAnnotation):
            guard let selectionRectInScreen else { return }
            let resizedAnnotation = resize(
                annotation: initialAnnotation, handle: handle, point: clamp(pointInScreen, to: selectionRectInScreen))
            updateAnnotation(id: id, with: resizedAnnotation)
        case .drawingAnnotation(var annotation):
            guard let selectionRectInScreen else { return }
            let clampedPoint = clamp(pointInScreen, to: selectionRectInScreen)
            if annotation.tool == .pen {
                annotation.points.append(clampedPoint)
            }
            annotation.endPoint = clampedPoint
            interaction = .drawingAnnotation(annotation: annotation)
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .creatingSelection:
            if mode == .quickSelect {
                // One-shot pick: releasing the mouse captures right away.
                if let selectionRectInScreen, selectionRectInScreen.width >= 8, selectionRectInScreen.height >= 8 {
                    interaction = .none
                    onComplete?(selectionRectInScreen, overlayScreen, [])
                    return
                }
                self.selectionRectInScreen = nil
            } else if let selectionRectInScreen, selectionRectInScreen.width >= minimumSelectionSize.width,
                selectionRectInScreen.height >= minimumSelectionSize.height
            {
                self.selectionRectInScreen = selectionRectInScreen
            } else {
                self.selectionRectInScreen = nil
            }
        case .drawingAnnotation(let annotation):
            if annotation.tool == .arrow {
                if annotation.bounds.width >= 8 || annotation.bounds.height >= 8 {
                    pushUndoSnapshot(annotations)
                    annotations.append(annotation)
                    selectedAnnotationID = annotation.id
                }
            } else if annotation.tool == .highlight {
                if annotation.bounds.width >= 12 && annotation.bounds.height >= 12 {
                    pushUndoSnapshot(annotations)
                    annotations.append(annotation)
                    selectedAnnotationID = annotation.id
                }
            } else if annotation.tool == .pen {
                if annotation.points.count >= 2 {
                    pushUndoSnapshot(annotations)
                    annotations.append(annotation)
                    selectedAnnotationID = annotation.id
                }
            }
        case .movingSelection, .resizingSelection, .movingAnnotation, .resizingAnnotation:
            commitAnnotationTransaction()
        case .none:
            break
        }

        interaction = .none
        needsDisplay = true
    }
}
