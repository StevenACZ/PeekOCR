// Live annotation overlay root view and shared state.

import AppKit

final class LiveAnnotationOverlayView: NSView {
    /// How the overlay behaves once a region is selected.
    enum OverlayMode {
        /// Full annotation session: adjust the selection, draw, capture on Enter.
        case annotate
        /// One-shot region pick: capture immediately on mouse-up (⌘⇧4-style).
        case quickSelect
    }

    enum Interaction {
        case none
        case creatingSelection(origin: CGPoint)
        case movingSelection(origin: CGPoint, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case resizingSelection(handle: SelectionHandle, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case movingAnnotation(id: UUID, origin: CGPoint, initialAnnotation: LiveAnnotation)
        case resizingAnnotation(id: UUID, handle: AnnotationHandle, initialAnnotation: LiveAnnotation)
        case drawingAnnotation(annotation: LiveAnnotation)
    }

    enum SelectionHandle: CaseIterable {
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

        var opposite: SelectionHandle {
            switch self {
            case .topLeft: return .bottomRight
            case .topRight: return .bottomLeft
            case .bottomLeft: return .topRight
            case .bottomRight: return .topLeft
            }
        }
    }

    /// Grab points on a selected annotation: rect corners for box-like
    /// annotations, the two endpoints for arrows.
    enum AnnotationHandle: Equatable {
        case corner(SelectionHandle)
        case arrowStart
        case arrowEnd
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
                if isEditingText {
                    dismissTextEditor(commit: true)
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

    var frozenBackgroundImage: CGImage? {
        didSet {
            needsDisplay = true
        }
    }

    var onCancel: (() -> Void)?
    var onComplete: ((CGRect, NSScreen, [LiveAnnotation]) -> Void)?

    /// The screen this overlay is rendering on. Set at construction.
    let overlayScreen: NSScreen

    /// Behavior of this overlay session. Set at construction.
    let mode: OverlayMode

    /// Fires the first time the user mousedowns on this overlay, so the window controller can dismiss sibling overlays.
    var onActivate: (() -> Void)?

    var didActivate = false

    init(screen: NSScreen, mode: OverlayMode = .annotate) {
        self.overlayScreen = screen
        self.mode = mode
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var interaction: Interaction = .none {
        didSet {
            needsDisplay = true
            refreshCursorAppearance()
        }
    }
    var pendingTextPoint: CGPoint?
    var editingAnnotationID: UUID?
    var textEditor: OverlayTextEditorView?
    var selectedAnnotationID: UUID?
    var annotationHistory: [[LiveAnnotation]] = []
    var annotationRedoStack: [[LiveAnnotation]] = []
    var pendingUndoSnapshot: [LiveAnnotation]?
    let maxAnnotationHistory = 50
    let appSettings = AppSettings.shared
    let accentColor = NSColor.systemBlue
    let annotationColor = NSColor.systemYellow
    /// Thumbnail-style lettering reads best as white fill over the black outline.
    let textColor = NSColor.white
    let minimumSelectionSize = CGSize(width: 40, height: 40)
    let minimumHighlightSize = CGSize(width: 12, height: 12)
    let annotationHandleSize: CGFloat = 10
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    // If activation was deferred by the system, the first click must already
    // start the selection instead of being swallowed by app activation.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func resetState() {
        selectionRectInScreen = nil
        selectedTool = .select
        annotations = []
        annotationHistory = []
        annotationRedoStack = []
        pendingUndoSnapshot = nil
        interaction = .none
        pendingTextPoint = nil
        editingAnnotationID = nil
        selectedAnnotationID = nil
        didActivate = false
        dismissTextEditor(commit: false)
        needsDisplay = true
    }

    func notifyActivationIfNeeded() {
        guard !didActivate else { return }
        didActivate = true
        onActivate?()
    }

    func beginQuickSelection(at pointInScreen: CGPoint) {
        guard mode == .quickSelect else { return }
        notifyActivationIfNeeded()
        let origin = clamp(pointInScreen, to: overlayScreen.frame)
        selectionRectInScreen = CGRect(origin: origin, size: .zero)
        interaction = .creatingSelection(origin: origin)
    }

    func updateQuickSelection(at pointInScreen: CGPoint) {
        guard mode == .quickSelect, case .creatingSelection(let origin) = interaction else { return }
        selectionRectInScreen = normalizedRect(from: origin, to: clamp(pointInScreen, to: overlayScreen.frame))
    }

    func finishQuickSelection() {
        guard mode == .quickSelect else { return }
        if let selectionRectInScreen, selectionRectInScreen.width >= 8, selectionRectInScreen.height >= 8 {
            interaction = .none
            onComplete?(selectionRectInScreen, overlayScreen, [])
            return
        }

        selectionRectInScreen = nil
        interaction = .none
        needsDisplay = true
    }

    func completeQuickSelectionWithFullScreen() {
        guard mode == .quickSelect, case .none = interaction else { return }
        notifyActivationIfNeeded()
        onComplete?(overlayScreen.frame, overlayScreen, [])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if mode == .annotate {
            window?.makeFirstResponder(self)
        }
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
        refreshCursorAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.activeAlways, .inVisibleRect, .mouseMoved, .cursorUpdate]
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
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "z" {
            if modifiers.contains(.shift) {
                redoLastAnnotationChange()
            } else {
                undoLastAnnotationChange()
            }
            return
        }

        if mode == .annotate, !modifiers.contains(.command),
            let characters = event.charactersIgnoringModifiers?.lowercased()
        {
            // Home-row tool shortcuts, matching toolbar order (A S D F G).
            switch characters {
            case "a":
                selectedTool = .select
                return
            case "s":
                selectedTool = .arrow
                return
            case "d":
                selectedTool = .text
                return
            case "f":
                selectedTool = .highlight
                return
            case "g":
                selectedTool = .pen
                return
            default:
                break
            }
        }

        switch event.keyCode {
        case 51, 117:  // delete / forward delete
            deleteSelectedAnnotation()
        case 53:  // esc
            if isEditingText {
                dismissTextEditor(commit: false)
            } else {
                onCancel?()
            }
        case 36, 76:  // return / enter
            if isEditingText {
                dismissTextEditor(commit: true)
                return
            }
            guard let selectionRectInScreen else { return }
            onComplete?(selectionRectInScreen, overlayScreen, annotations)
        case 49:  // space: full-screen pick (quick select only)
            guard mode == .quickSelect, case .none = interaction else {
                super.keyDown(with: event)
                return
            }
            notifyActivationIfNeeded()
            onComplete?(overlayScreen.frame, overlayScreen, [])
        default:
            super.keyDown(with: event)
        }
    }

}
