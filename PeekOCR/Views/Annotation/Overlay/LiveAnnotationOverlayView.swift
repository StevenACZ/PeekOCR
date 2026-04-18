import AppKit

final class LiveAnnotationOverlayView: NSView {
    private enum Interaction {
        case none
        case creatingSelection(origin: CGPoint)
        case movingSelection(origin: CGPoint, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case resizingSelection(handle: SelectionHandle, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case movingAnnotation(id: UUID, origin: CGPoint, initialAnnotation: LiveAnnotation)
        case resizingAnnotation(id: UUID, handle: SelectionHandle, initialAnnotation: LiveAnnotation)
        case drawingAnnotation(annotation: LiveAnnotation)
    }

    private enum SelectionHandle: CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        func point(for rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
            case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
            case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
            case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
            }
        }
    }

    var selectionRectInScreen: CGRect? {
        didSet {
            needsDisplay = true
            refreshCursorAppearance()
        }
    }

    var selectedTool: LiveAnnotationTool = .select {
        didSet {
            if oldValue != selectedTool {
                if textField != nil {
                    removeTextField(commit: true)
                }
                selectedAnnotationID = nil
                if case .drawingAnnotation = interaction {
                    interaction = .none
                }
            }
            needsDisplay = true
            refreshCursorAppearance()
        }
    }

    var annotations: [LiveAnnotation] = [] {
        didSet {
            needsDisplay = true
            refreshCursorAppearance()
        }
    }

    var onCancel: (() -> Void)?
    var onComplete: ((CGRect, NSScreen, [LiveAnnotation]) -> Void)?

    /// The screen this overlay is rendering on. Set at construction.
    let overlayScreen: NSScreen

    /// Fires the first time the user mousedowns on this overlay, so the window controller can dismiss sibling overlays.
    var onActivate: (() -> Void)?

    private var didActivate = false

    init(screen: NSScreen) {
        self.overlayScreen = screen
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var interaction: Interaction = .none {
        didSet {
            needsDisplay = true
            refreshCursorAppearance()
        }
    }
    private var pendingTextPoint: CGPoint?
    private var editingAnnotationID: UUID?
    private var textField: NSTextField?
    private var selectedAnnotationID: UUID?
    private var annotationHistory: [[LiveAnnotation]] = []
    private let maxAnnotationHistory = 50
    private let appSettings = AppSettings.shared
    private let accentColor = NSColor.systemBlue
    private let annotationColor = NSColor.systemYellow
    private let minimumSelectionSize = CGSize(width: 40, height: 40)
    private let minimumHighlightSize = CGSize(width: 12, height: 12)
    private let annotationHandleSize: CGFloat = 10
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    func resetState() {
        selectionRectInScreen = nil
        selectedTool = .select
        annotations = []
        annotationHistory = []
        interaction = .none
        pendingTextPoint = nil
        editingAnnotationID = nil
        selectedAnnotationID = nil
        didActivate = false
        removeTextField(commit: false)
        needsDisplay = true
    }

    private func notifyActivationIfNeeded() {
        guard !didActivate else { return }
        didActivate = true
        onActivate?()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
        refreshCursorAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .cursorUpdate]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: currentCursor())
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(for: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "z" {
            undoLastAnnotationChange()
            return
        }

        if let characters = event.charactersIgnoringModifiers?.lowercased() {
            switch characters {
            case "s":
                selectedTool = .select
                return
            case "a":
                selectedTool = .arrow
                return
            case "t":
                selectedTool = .text
                return
            case "h":
                selectedTool = .highlight
                return
            default:
                break
            }
        }

        switch event.keyCode {
        case 53: // esc
            if textField != nil {
                removeTextField(commit: false)
            } else {
                onCancel?()
            }
        case 36, 76: // return / enter
            if textField != nil {
                removeTextField(commit: true)
                return
            }
            guard let selectionRectInScreen else { return }
            onComplete?(selectionRectInScreen, overlayScreen, annotations)
        default:
            super.keyDown(with: event)
        }
    }

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
           let handle = hitTestAnnotationResizeHandle(for: annotation, at: pointInScreen) {
            notifyActivationIfNeeded()
            recordAnnotationSnapshot()
            interaction = .resizingAnnotation(id: annotationID, handle: handle, initialAnnotation: annotation)
            return
        }

        if let selectionRectInScreen,
           let handle = hitTestHandle(at: pointInScreen, selectionRectInScreen: selectionRectInScreen) {
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
               let annotation = annotations.first(where: { $0.id == annotationID }) {
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
            let resizedAnnotation = resize(annotation: initialAnnotation, handle: handle, point: clamp(pointInScreen, to: selectionRectInScreen))
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
            if let selectionRectInScreen, selectionRectInScreen.width >= minimumSelectionSize.width, selectionRectInScreen.height >= minimumSelectionSize.height {
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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let window else { return }

        NSColor.clear.setFill()
        dirtyRect.fill()

        if let selectionRectInScreen {
            let selectionRect = convert(window.convertFromScreen(selectionRectInScreen), from: nil)
            let overlayPath = NSBezierPath(rect: bounds)
            overlayPath.appendRect(selectionRect)
            overlayPath.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.35).setFill()
            overlayPath.fill()

            let border = NSBezierPath(roundedRect: selectionRect, xRadius: 8, yRadius: 8)
            accentColor.setStroke()
            border.lineWidth = 2
            border.stroke()

            drawSelectionHandles(in: selectionRect)
            LiveAnnotationRenderer.drawOverlayAnnotations(annotationsForDrawing, in: self, window: window, selectionRectInScreen: selectionRectInScreen)
            drawSelectedAnnotationIfNeeded(in: self, window: window)
            drawToolbar(in: selectionRect)
            drawInstructions(in: selectionRect)
        } else {
            NSColor.black.withAlphaComponent(0.12).setFill()
            bounds.fill()
            drawCenteredHint(text: "Arrastra para seleccionar • S mover/ajustar • A flecha • T texto • H highlight • Enter capturar • Esc cancelar")
        }
    }

    private var annotationsForDrawing: [LiveAnnotation] {
        switch interaction {
        case .drawingAnnotation(let annotation):
            return annotations + [annotation]
        default:
            return annotations
        }
    }

    private func drawSelectionHandles(in rect: CGRect) {
        SelectionHandle.allCases.forEach { handle in
            let point = viewPoint(from: handle.point(for: screenRect(from: rect)))
            let handleRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            accentColor.setStroke()
            let stroke = NSBezierPath(ovalIn: handleRect)
            stroke.lineWidth = 1.5
            stroke.stroke()
        }
    }

    private func drawToolbar(in selectionRect: CGRect) {
        let buttons = toolbarButtonFrames(in: selectionRect)
        let background = buttons.values.reduce(into: CGRect.null) { partialResult, rect in
            partialResult = partialResult.union(rect)
        }.insetBy(dx: -8, dy: -8).standardized
        guard !background.isNull else { return }

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: background, xRadius: 12, yRadius: 12).fill()

        for tool in LiveAnnotationTool.allCases {
            guard let frame = buttons[tool] else { continue }
            let selected = tool == selectedTool
            let fill = selected ? accentColor.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.08)
            fill.setFill()
            NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
            ]
            let title = "\(tool.displayName)\n\(tool.shortcutKey)"
            title.draw(in: frame.insetBy(dx: 6, dy: 8), withAttributes: attributes)
        }
    }

    private func drawInstructions(in selectionRect: CGRect) {
        let text = "Arrastra bordes para ajustar • Arrastra dentro para mover • Enter captura • Esc cancela"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: selectionRect.minX + 12,
            y: max(selectionRect.minY - 34, 16),
            width: size.width + 20,
            height: size.height + 10
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5), withAttributes: attributes)
    }

    private func drawCenteredHint(text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(
            x: bounds.midX - size.width / 2 - 14,
            y: bounds.midY - size.height / 2 - 8,
            width: size.width + 28,
            height: size.height + 16
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 8), withAttributes: attributes)
    }

    private func handleToolbarClick(at pointInScreen: CGPoint) -> Bool {
        guard let selectionRectInScreen else { return false }
        let selectionRect = convert(window?.convertFromScreen(selectionRectInScreen) ?? .zero, from: nil)
        let pointInView = viewPoint(from: pointInScreen)

        for (tool, frame) in toolbarButtonFrames(in: selectionRect) where frame.contains(pointInView) {
            selectedTool = tool
            needsDisplay = true
            return true
        }

        return false
    }

    private func toolbarButtonFrames(in selectionRect: CGRect) -> [LiveAnnotationTool: CGRect] {
        let buttonSize = CGSize(width: 78, height: 42)
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(LiveAnnotationTool.allCases.count) * buttonSize.width + CGFloat(LiveAnnotationTool.allCases.count - 1) * spacing
        let origin = CGPoint(
            x: selectionRect.midX - totalWidth / 2,
            y: min(selectionRect.maxY + 14, bounds.maxY - buttonSize.height - 20)
        )

        var frames: [LiveAnnotationTool: CGRect] = [:]
        for (index, tool) in LiveAnnotationTool.allCases.enumerated() {
            frames[tool] = CGRect(
                x: origin.x + CGFloat(index) * (buttonSize.width + spacing),
                y: origin.y,
                width: buttonSize.width,
                height: buttonSize.height
            )
        }
        return frames
    }

    private func beginTextInput(at pointInScreen: CGPoint) {
        guard let selectionRectInScreen, selectionRectInScreen.contains(pointInScreen) else { return }
        removeTextField(commit: true)
        pendingTextPoint = pointInScreen
        editingAnnotationID = nil
        showTextField(at: pointInScreen, initialText: "")
    }

    private func beginTextInput(for annotation: LiveAnnotation) {
        removeTextField(commit: true)
        pendingTextPoint = annotation.startPoint
        editingAnnotationID = annotation.id
        selectedAnnotationID = annotation.id
        showTextField(at: annotation.startPoint, initialText: annotation.text)
    }

    private func showTextField(at pointInScreen: CGPoint, initialText: String) {
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

    private func removeTextField(commit: Bool) {
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
           let existing = annotations.first(where: { $0.id == editingAnnotationID }) {
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

    private func hitTestHandle(at point: CGPoint, selectionRectInScreen: CGRect) -> SelectionHandle? {
        for handle in SelectionHandle.allCases {
            let handleRect = CGRect(origin: handle.point(for: selectionRectInScreen), size: .zero).insetBy(dx: -10, dy: -10)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    private func hitTestAnnotation(at point: CGPoint) -> UUID? {
        for annotation in annotations.reversed() {
            switch annotation.tool {
            case .arrow:
                if HitTestEngine.hitTestLine(from: annotation.startPoint, to: annotation.endPoint, point: point, tolerance: 12) {
                    return annotation.id
                }
            case .highlight:
                if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
                    return annotation.id
                }
            case .text:
                if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
                    return annotation.id
                }
            case .select:
                break
            }
        }
        return nil
    }

    private func hitTestAnnotationResizeHandle(for annotation: LiveAnnotation, at point: CGPoint) -> SelectionHandle? {
        guard annotation.tool == .highlight else { return nil }

        for handle in SelectionHandle.allCases {
            let handleRect = CGRect(origin: handle.point(for: annotation.bounds), size: .zero)
                .insetBy(dx: -12, dy: -12)
            if handleRect.contains(point) {
                return handle
            }
        }

        return nil
    }

    private func drawSelectedAnnotationIfNeeded(in view: NSView, window: NSWindow) {
        guard let selectedAnnotationID,
              let annotation = annotations.first(where: { $0.id == selectedAnnotationID }) else { return }

        let rectInView = rectInView(from: annotation.bounds).insetBy(dx: -6, dy: -6)
        let path = NSBezierPath(roundedRect: rectInView, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()

        if annotation.tool == .highlight {
            drawAnnotationResizeHandles(for: annotation)
        }
    }

    private func drawAnnotationResizeHandles(for annotation: LiveAnnotation) {
        for handle in SelectionHandle.allCases {
            let point = viewPoint(from: handle.point(for: annotation.bounds))
            let handleRect = CGRect(
                x: point.x - annotationHandleSize / 2,
                y: point.y - annotationHandleSize / 2,
                width: annotationHandleSize,
                height: annotationHandleSize
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            annotation.color.setStroke()
            let stroke = NSBezierPath(ovalIn: handleRect)
            stroke.lineWidth = 1.5
            stroke.stroke()
        }
    }

    private func updateAnnotation(id: UUID, with updatedAnnotation: LiveAnnotation) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = updatedAnnotation
    }

    private func recordAnnotationSnapshot() {
        annotationHistory.append(annotations)
        if annotationHistory.count > maxAnnotationHistory {
            annotationHistory.removeFirst(annotationHistory.count - maxAnnotationHistory)
        }
    }

    private func undoLastAnnotationChange() {
        removeTextField(commit: false)
        guard let previousAnnotations = annotationHistory.popLast() else { return }
        annotations = previousAnnotations
        if let selectedAnnotationID,
           !annotations.contains(where: { $0.id == selectedAnnotationID }) {
            self.selectedAnnotationID = nil
        }
        interaction = .none
    }

    private func translated(annotation: LiveAnnotation, dx: CGFloat, dy: CGFloat) -> LiveAnnotation {
        var annotation = annotation
        annotation.startPoint.x += dx
        annotation.startPoint.y += dy
        annotation.endPoint.x += dx
        annotation.endPoint.y += dy
        return annotation
    }

    private func resize(annotation: LiveAnnotation, handle: SelectionHandle, point: CGPoint) -> LiveAnnotation {
        var minX = annotation.bounds.minX
        var maxX = annotation.bounds.maxX
        var minY = annotation.bounds.minY
        var maxY = annotation.bounds.maxY

        switch handle {
        case .topLeft:
            minX = point.x
            maxY = point.y
        case .topRight:
            maxX = point.x
            maxY = point.y
        case .bottomLeft:
            minX = point.x
            minY = point.y
        case .bottomRight:
            maxX = point.x
            minY = point.y
        }

        if maxX - minX < minimumHighlightSize.width {
            if handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minimumHighlightSize.width
            } else {
                maxX = minX + minimumHighlightSize.width
            }
        }

        if maxY - minY < minimumHighlightSize.height {
            if handle == .bottomLeft || handle == .bottomRight {
                minY = maxY - minimumHighlightSize.height
            } else {
                maxY = minY + minimumHighlightSize.height
            }
        }

        var resizedAnnotation = annotation
        resizedAnnotation.startPoint = CGPoint(x: minX, y: minY)
        resizedAnnotation.endPoint = CGPoint(x: maxX, y: maxY)
        return resizedAnnotation
    }

    private func resize(initialRect: CGRect, handle: SelectionHandle, point: CGPoint) -> CGRect {
        var minX = initialRect.minX
        var maxX = initialRect.maxX
        var minY = initialRect.minY
        var maxY = initialRect.maxY

        switch handle {
        case .topLeft:
            minX = point.x
            maxY = point.y
        case .topRight:
            maxX = point.x
            maxY = point.y
        case .bottomLeft:
            minX = point.x
            minY = point.y
        case .bottomRight:
            maxX = point.x
            minY = point.y
        }

        if maxX - minX < minimumSelectionSize.width {
            if handle == .topLeft || handle == .bottomLeft {
                minX = maxX - minimumSelectionSize.width
            } else {
                maxX = minX + minimumSelectionSize.width
            }
        }

        if maxY - minY < minimumSelectionSize.height {
            if handle == .bottomLeft || handle == .bottomRight {
                minY = maxY - minimumSelectionSize.height
            } else {
                maxY = minY + minimumSelectionSize.height
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func translated(_ annotations: [LiveAnnotation], dx: CGFloat, dy: CGFloat) -> [LiveAnnotation] {
        annotations.map { annotation in
            var annotation = annotation
            annotation.startPoint.x += dx
            annotation.startPoint.y += dy
            annotation.endPoint.x += dx
            annotation.endPoint.y += dy
            return annotation
        }
    }

    private func transformed(_ annotations: [LiveAnnotation], from initialRect: CGRect, to newRect: CGRect) -> [LiveAnnotation] {
        guard initialRect.width > 0, initialRect.height > 0 else { return annotations }
        let scaleX = newRect.width / initialRect.width
        let scaleY = newRect.height / initialRect.height
        let fontScale = max(0.75, min(scaleX, scaleY))

        return annotations.map { annotation in
            var annotation = annotation
            annotation.startPoint = transform(point: annotation.startPoint, from: initialRect, to: newRect)
            annotation.endPoint = transform(point: annotation.endPoint, from: initialRect, to: newRect)
            if annotation.tool == .text {
                annotation.fontSize *= fontScale
            }
            return annotation
        }
    }

    private func transform(point: CGPoint, from initialRect: CGRect, to newRect: CGRect) -> CGPoint {
        let relativeX = (point.x - initialRect.minX) / initialRect.width
        let relativeY = (point.y - initialRect.minY) / initialRect.height
        return CGPoint(
            x: newRect.minX + relativeX * newRect.width,
            y: newRect.minY + relativeY * newRect.height
        )
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func clamp(rect: CGRect, to bounds: CGRect) -> CGRect {
        var rect = rect
        if rect.minX < bounds.minX { rect.origin.x = bounds.minX }
        if rect.minY < bounds.minY { rect.origin.y = bounds.minY }
        if rect.maxX > bounds.maxX { rect.origin.x = bounds.maxX - rect.width }
        if rect.maxY > bounds.maxY { rect.origin.y = bounds.maxY - rect.height }
        return rect
    }

    private func currentCursor() -> NSCursor {
        if let pointInScreen = currentMouseLocationInScreen() {
            return cursor(for: pointInScreen)
        }

        if selectionRectInScreen == nil {
            return .crosshair
        }

        return selectedTool == .text ? .iBeam : .openHand
    }

    private func cursor(for pointInScreen: CGPoint) -> NSCursor {
        switch interaction {
        case .movingSelection, .movingAnnotation:
            return .closedHand
        case .resizingSelection, .resizingAnnotation:
            return .closedHand
        case .creatingSelection, .drawingAnnotation:
            return .crosshair
        case .none:
            break
        }

        if isPointInToolbar(pointInScreen) {
            return .pointingHand
        }

        if let selectedAnnotationID,
           let annotation = annotations.first(where: { $0.id == selectedAnnotationID }),
           hitTestAnnotationResizeHandle(for: annotation, at: pointInScreen) != nil {
            return .openHand
        }

        if let selectionRectInScreen,
           hitTestHandle(at: pointInScreen, selectionRectInScreen: selectionRectInScreen) != nil {
            return .openHand
        }

        if hitTestAnnotation(at: pointInScreen) != nil {
            return .openHand
        }

        guard let selectionRectInScreen else {
            return .crosshair
        }

        if selectionRectInScreen.contains(pointInScreen) {
            switch selectedTool {
            case .text:
                return .iBeam
            case .select:
                return .openHand
            case .arrow, .highlight:
                return .crosshair
            }
        }

        return .crosshair
    }

    private func refreshCursorAppearance() {
        window?.invalidateCursorRects(for: self)
        updateCursor()
    }

    private func updateCursor() {
        currentCursor().set()
    }

    private func updateCursor(for event: NSEvent) {
        guard let window else {
            updateCursor()
            return
        }

        let pointInScreen = screenPoint(from: event.locationInWindow, window: window)
        cursor(for: pointInScreen).set()
    }

    private func currentMouseLocationInScreen() -> CGPoint? {
        guard let window else { return nil }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        return screenPoint(from: mouseInWindow, window: window)
    }

    private func isPointInToolbar(_ pointInScreen: CGPoint) -> Bool {
        guard let selectionRectInScreen else { return false }
        let selectionRect = convert(window?.convertFromScreen(selectionRectInScreen) ?? .zero, from: nil)
        let pointInView = viewPoint(from: pointInScreen)
        return toolbarButtonFrames(in: selectionRect).values.contains { $0.contains(pointInView) }
    }

    private func screenPoint(from pointInWindow: CGPoint, window: NSWindow) -> CGPoint {
        window.convertToScreen(CGRect(origin: pointInWindow, size: .zero)).origin
    }

    private func screenRect(from rectInView: CGRect) -> CGRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(rectInView, to: nil))
    }

    private func viewPoint(from screenPoint: CGPoint) -> CGPoint {
        guard let window else { return .zero }
        let pointInWindow = window.convertFromScreen(CGRect(origin: screenPoint, size: .zero)).origin
        return convert(pointInWindow, from: nil)
    }

    private func rectInView(from screenRect: CGRect) -> CGRect {
        guard let window else { return .zero }
        let rectInWindow = window.convertFromScreen(screenRect)
        return convert(rectInWindow, from: nil)
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

