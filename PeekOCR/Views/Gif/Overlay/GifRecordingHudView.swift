//
//  GifRecordingHudView.swift
//  PeekOCR
//
//  Small HUD view that shows recording countdown and a stop button.
//

import AppKit

/// Heads-up display shown while recording a GIF clip.
final class GifRecordingHudView: NSView {
    var elapsedSeconds: Int = 0 {
        didSet { updateLabel() }
    }

    var onStop: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let stopButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        updateLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Private

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white

        stopButton.target = self
        stopButton.action = #selector(stopPressed)
        stopButton.isBordered = false
        stopButton.bezelStyle = .regularSquare
        stopButton.contentTintColor = .white
        stopButton.toolTip = "Detener grabación"
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")

        let stack = NSStackView(views: [label, stopButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 10)

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            stopButton.widthAnchor.constraint(equalToConstant: 22),
            stopButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    private func updateLabel() {
        let elapsed = max(0, elapsedSeconds)
        let text = "● REC  \(elapsed)s"

        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        if let dotRange = text.range(of: "●") {
            let nsRange = NSRange(dotRange, in: text)
            attributed.addAttribute(.foregroundColor, value: NSColor.systemRed, range: nsRange)
        }

        label.attributedStringValue = attributed
        invalidateIntrinsicContentSize()
    }

    @objc
    private func stopPressed() {
        onStop?()
    }
}
