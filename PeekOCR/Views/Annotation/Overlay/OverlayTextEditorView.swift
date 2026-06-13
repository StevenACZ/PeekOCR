// Floating multi-line text editor for the live annotation overlay.
// Enter inserts a new line; ⌘Enter commits; Esc cancels.

import AppKit

final class OverlayTextEditorView: NSView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Fired whenever the text layout changes so the owner can refit the frame.
    var onTextChange: (() -> Void)?

    /// Inner padding between the rounded background and the text itself.
    let padding = CGSize(width: 8, height: 6)
    /// Extra horizontal room inside the text view so the black outline of the
    /// first/last glyphs doesn't get clipped by the view bounds.
    private let textInset: CGSize

    private let textView: OverlayTextView
    private let fontSize: CGFloat

    var text: String { textView.string }

    init(initialText: String, fontSize: CGFloat, color: NSColor) {
        self.fontSize = fontSize
        self.textInset = CGSize(width: max(3, ceil(fontSize * 0.15)), height: 0)
        self.textView = OverlayTextView()

        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1.5
        layer?.borderColor = color.withAlphaComponent(0.6).cgColor

        textView.string = initialText
        let attributes = LiveAnnotation.editorTextAttributes(fontSize: fontSize, color: color)
        textView.typingAttributes = attributes
        textView.textStorage?.setAttributes(
            attributes, range: NSRange(location: 0, length: (initialText as NSString).length))
        textView.insertionPointColor = color
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
        let textSize = LiveAnnotation.textSize(for: textView.string, fontSize: fontSize)
        return CGSize(
            width: max(140, textSize.width) + (padding.width + textInset.width) * 2,
            height: textSize.height + padding.height * 2
        )
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
