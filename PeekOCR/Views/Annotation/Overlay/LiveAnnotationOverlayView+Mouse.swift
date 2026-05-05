// Live annotation overlay mouse interaction handling.

import AppKit

extension LiveAnnotationOverlayView {
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let pointInScreen = screenPoint(from: event.locationInWindow, window: window)

        if textField != nil {
            if handleToolbarClick(at: pointInScreen) {
                removeTextField(commit: true)
                return
            }

            removeTextField(commit: true)
            return
        }

        if handleToolbarClick(at: pointInScreen) {
            return
        }

        removeTextField(commit: true)

        if let annotationID = selectedAnnotationID,
            let annotation = annotations.first(where: { $0.id == annotationID }),
            annotation.tool == .highlight,
            let handle = hitTestAnnotationResizeHandle(for: annotation, at: pointInScreen)
        {
            notifyActivationIfNeeded()
            recordAnnotationSnapshot()
            interaction = .resizingAnnotation(id: annotationID, handle: handle, initialAnnotation: annotation)
            return
        }

        if let selectionRectInScreen,
            let handle = hitTestHandle(at: pointInScreen, selectionRectInScreen: selectionRectInScreen)
        {
            notifyActivationIfNeeded()
            selectedAnnotationID = nil
            if !annotations.isEmpty {
                recordAnnotationSnapshot()
            }
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

                recordAnnotationSnapshot()
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
                if !annotations.isEmpty {
                    recordAnnotationSnapshot()
                }
                interaction = .movingSelection(origin: pointInScreen, initialRect: selectionRectInScreen, initialAnnotations: annotations)
            case .text:
                notifyActivationIfNeeded()
                beginTextInput(at: pointInScreen)
            case .arrow, .highlight:
                notifyActivationIfNeeded()
                let annotation = LiveAnnotation(
                    tool: selectedTool,
                    color: selectedTool == .highlight ? annotationColor : accentColor,
                    startPoint: pointInScreen,
                    endPoint: pointInScreen,
                    text: "",
                    fontSize: CGFloat(appSettings.defaultAnnotationFontSize),
                    strokeWidth: CGFloat(appSettings.defaultAnnotationStrokeWidth)
                )
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
            annotation.endPoint = clamp(pointInScreen, to: selectionRectInScreen)
            interaction = .drawingAnnotation(annotation: annotation)
        }
    }

    override func mouseUp(with event: NSEvent) {
        switch interaction {
        case .creatingSelection:
            if let selectionRectInScreen, selectionRectInScreen.width >= minimumSelectionSize.width,
                selectionRectInScreen.height >= minimumSelectionSize.height
            {
                self.selectionRectInScreen = selectionRectInScreen
            } else {
                self.selectionRectInScreen = nil
            }
        case .drawingAnnotation(let annotation):
            if annotation.tool == .arrow {
                if annotation.bounds.width >= 8 || annotation.bounds.height >= 8 {
                    recordAnnotationSnapshot()
                    annotations.append(annotation)
                    selectedAnnotationID = annotation.id
                }
            } else if annotation.tool == .highlight {
                if annotation.bounds.width >= 12 && annotation.bounds.height >= 12 {
                    recordAnnotationSnapshot()
                    annotations.append(annotation)
                    selectedAnnotationID = annotation.id
                }
            }
        case .movingSelection, .resizingSelection, .movingAnnotation, .resizingAnnotation, .none:
            break
        }

        interaction = .none
        needsDisplay = true
    }
}
