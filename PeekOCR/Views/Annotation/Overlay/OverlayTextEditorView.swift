// Floating multi-line text editor for the live annotation overlay.
// Enter inserts a new line; ⌘Enter commits; Esc cancels.

import AppKit

final class OverlayTextEditorView: NSView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Fired whenever the text layout changes so the owner can refit the frame.
    var onTextChange: (() -> Void)?

    /// Inner padding between the rounded background and the text itself.
    private let padding: CGSize
    /// Extra horizontal room inside the text view so the black outline of the
    /// first/last glyphs doesn't get clipped by the view bounds.
    private let textInset: CGSize

    private let textView: OverlayTextView
    private let fontSize: CGFloat
    private let color: NSColor
    private let placeholder = "annotation.text_placeholder".localized

    var text: String { textView.string }

    private var displayedText: String { textView.string.isEmpty ? placeholder : textView.string }

    init(initialText: String, fontSize: CGFloat, color: NSColor) {
        self.fontSize = fontSize
        self.color = color
        self.padding = CGSize(width: 8, height: max(6, ceil(fontSize * LiveAnnotation.textOutlineFraction / 2)))
        self.textInset = CGSize(width: max(3, ceil(fontSize * 0.15)), height: 0)
        self.textView = OverlayTextView()

        super.init(frame: .zero)

        wantsLayer = true

        // The text view only edits: its glyphs are clear and `draw` paints the real lettering underneath.
        textView.string = initialText
        let attributes: [NSAttributedString.Key: Any] = [
            .font: LiveAnnotation.textFont(ofSize: fontSize),
            .foregroundColor: NSColor.clear,
        ]
        textView.typingAttributes = attributes
        textView.textStorage?.setAttributes(
            attributes, range: NSRange(location: 0, length: (initialText as NSString).length))
        textView.insertionPointColor = color
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.45)
        ]
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = textInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.delegate = self
        textView.onCommit = { [weak self] in self?.onCommit?() }
        textView.onCancel = { [weak self] in self?.onCancel?() }
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Size the editor needs for its current text (content plus padding).
    var desiredSize: CGSize {
        let textSize = LiveAnnotation.textSize(for: displayedText, fontSize: fontSize)
        return CGSize(
            width: textSize.width + (padding.width + textInset.width) * 2,
            height: textSize.height + padding.height * 2
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.3).setFill()
        frame.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        frame.lineWidth = 1.5
        frame.setLineDash([6, 4], count: 2, phase: 0)
        frame.stroke()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let size = LiveAnnotation.textSize(for: displayedText, fontSize: fontSize)
        let rect = CGRect(
            x: padding.width + textInset.width, y: bounds.maxY - padding.height - size.height,
            width: size.width, height: size.height)
        context.saveGState()
        context.setAlpha(textView.string.isEmpty ? 0.4 : 1)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        LiveAnnotationRenderer.drawThumbnailText(displayedText, in: rect, fontSize: fontSize, color: color)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// Frame so the first typed glyph lands exactly at `topLeft` (the point
    /// where the committed annotation will render).
    func frame(anchoredAtTextTopLeft topLeft: CGPoint) -> CGRect {
        let size = desiredSize
        return CGRect(
            x: topLeft.x - padding.width - textInset.width,
            y: topLeft.y + padding.height - size.height,
            width: size.width,
            height: size.height
        )
    }

    override func layout() {
        super.layout()
        textView.frame = bounds.insetBy(dx: padding.width, dy: padding.height)
    }

    func focus(in window: NSWindow) {
        window.makeFirstResponder(textView)
    }
}

extension OverlayTextEditorView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        needsDisplay = true
        onTextChange?()
    }
}

/// Text view that owns the overlay-specific key handling. The standard editing
/// equivalents (⌘Z/⌘C/⌘V/…) are mapped manually because accessory apps may run
/// without an Edit menu to route them.
private final class OverlayTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // esc
            onCancel?()
            return
        }
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn, !event.modifierFlags.contains(.shift), !hasMarkedText() {  // ⇧enter keeps the newline
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        if event.keyCode == 36 || event.keyCode == 76 {  // ⌘enter commits
            onCommit?()
            return true
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z":
            if modifiers.contains(.shift) {
                undoManager?.redo()
            } else {
                undoManager?.undo()
            }
            return true
        case "c":
            copy(nil)
            return true
        case "v":
            paste(nil)
            return true
        case "x":
            cut(nil)
            return true
        case "a":
            selectAll(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
