// Live annotation overlay root view and shared state.

import AppKit

final class LiveAnnotationOverlayView: NSView {
    enum Interaction {
        case none
        case creatingSelection(origin: CGPoint)
        case movingSelection(origin: CGPoint, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case resizingSelection(handle: SelectionHandle, initialRect: CGRect, initialAnnotations: [LiveAnnotation])
        case movingAnnotation(id: UUID, origin: CGPoint, initialAnnotation: LiveAnnotation)
        case resizingAnnotation(id: UUID, handle: SelectionHandle, initialAnnotation: LiveAnnotation)
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

    var didActivate = false

    init(screen: NSScreen) {
        self.overlayScreen = screen
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
    var textField: NSTextField?
    var selectedAnnotationID: UUID?
    var annotationHistory: [[LiveAnnotation]] = []
    let maxAnnotationHistory = 50
    let appSettings = AppSettings.shared
    let accentColor = NSColor.systemBlue
    let annotationColor = NSColor.systemYellow
    let minimumSelectionSize = CGSize(width: 40, height: 40)
    let minimumHighlightSize = CGSize(width: 12, height: 12)
    let annotationHandleSize: CGFloat = 10
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

    func notifyActivationIfNeeded() {
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
            event.charactersIgnoringModifiers?.lowercased() == "z"
        {
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
        case 53:  // esc
            if textField != nil {
                removeTextField(commit: false)
            } else {
                onCancel?()
            }
        case 36, 76:  // return / enter
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

}
