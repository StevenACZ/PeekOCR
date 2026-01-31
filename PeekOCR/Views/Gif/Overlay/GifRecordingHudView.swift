//
//  GifRecordingHudView.swift
//  PeekOCR
//
//  Small HUD view that shows recording status, timer, and controls.
//

import AppKit

/// Heads-up display shown while recording a clip (outside the captured region).
final class GifRecordingHudView: NSView {
    var elapsedSeconds: Int = 0 { didSet { updateUI() } }
    var maxDurationSeconds: Int = 0 { didSet { updateUI() } }

    var onStop: (() -> Void)?

    private let backgroundView = NSVisualEffectView()
    private let dotView = NSView()
    private let recLabel = NSTextField(labelWithString: "REC")
    private let timerLabel = NSTextField(labelWithString: "00:00")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progressView = HudProgressBarView(frame: .zero)
    private let stopButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        updateUI()
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
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 14
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4.5
        dotView.layer?.backgroundColor = NSColor.systemRed.cgColor

        recLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        recLabel.textColor = .white

        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        timerLabel.textColor = .white

        subtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.75)

        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = NSColor.white.withAlphaComponent(0.18)

        stopButton.target = self
        stopButton.action = #selector(stopPressed)
        stopButton.bezelStyle = .texturedRounded
        stopButton.isBordered = true
        stopButton.contentTintColor = .white
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        stopButton.toolTip = "Detener"

        let leftStack = NSStackView(views: [dotView, recLabel])
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 8

        let centerStack = NSStackView(views: [timerLabel, subtitleLabel, progressView])
        centerStack.orientation = .vertical
        centerStack.alignment = .leading
        centerStack.spacing = 4

        let root = NSStackView(views: [leftStack, centerStack, stopButton])
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        addSubview(root)
        root.translatesAutoresizingMaskIntoConstraints = false
        dotView.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),

            dotView.widthAnchor.constraint(equalToConstant: 9),
            dotView.heightAnchor.constraint(equalToConstant: 9),

            stopButton.widthAnchor.constraint(equalToConstant: 30),
            stopButton.heightAnchor.constraint(equalToConstant: 30),

            progressView.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            progressView.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    private func updateUI() {
        let elapsed = max(0, elapsedSeconds)
        let maxDuration = max(0, maxDurationSeconds)
        let remaining = max(0, maxDuration - elapsed)

        timerLabel.stringValue = formatTime(seconds: remaining)
        subtitleLabel.stringValue = "Restante"

        let progress = (maxDuration > 0) ? (Double(elapsed) / Double(maxDuration)) : 0
        progressView.progress = progress

        invalidateIntrinsicContentSize()
    }

    private func formatTime(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    @objc
    private func stopPressed() {
        onStop?()
    }
}

private final class HudProgressBarView: NSView {
    var progress: Double = 0 { didSet { needsLayout = true } }
    var progressTintColor: NSColor = .systemBlue { didSet { updateColors() } }
    var trackTintColor: NSColor = NSColor.white.withAlphaComponent(0.18) { didSet { updateColors() } }

    private let trackLayer = CALayer()
    private let fillLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let radius = bounds.height / 2
        trackLayer.frame = bounds
        trackLayer.cornerRadius = radius
        trackLayer.masksToBounds = true

        let clamped = min(1, max(0, progress))
        fillLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * clamped, height: bounds.height)
        fillLayer.cornerRadius = radius
        fillLayer.masksToBounds = true

        CATransaction.commit()
    }

    private func updateColors() {
        trackLayer.backgroundColor = trackTintColor.cgColor
        fillLayer.backgroundColor = progressTintColor.cgColor
    }
}
