//
//  RecordingHudView.swift
//  PeekOCR
//
//  Compact pill that shows recording status, timer, and controls.
//

import AppKit

/// Compact pill shown next to the recorded region: status dot, timer,
/// quality readout, pause and stop.
final class RecordingHudView: NSView {
    var elapsedSeconds: Int = 0 { didSet { updateUI() } }
    var maxDurationSeconds: Int = 0 { didSet { updateUI() } }
    /// "1080p · 30 FPS · GIF" readout shown next to the timer.
    var qualityText: String = "" { didSet { updateUI() } }
    var isPaused: Bool = false { didSet { updateUI() } }

    var onStop: (() -> Void)?
    var onTogglePause: (() -> Void)?

    private static let height: CGFloat = 38

    private let backgroundView = NSVisualEffectView()
    private let dotView = NSView()
    private let timerLabel = NSTextField(labelWithString: "00:00")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progressView = HudProgressBarView(frame: .zero)
    private let pauseButton = HudButton(symbolName: "pause.fill", baseColor: NSColor.white.withAlphaComponent(0.12))
    private let stopButton = HudButton(symbolName: "stop.fill", baseColor: .systemRed)

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
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = Self.height / 2
        layer?.masksToBounds = true

        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Self.height / 2
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4

        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timerLabel.textColor = .white
        timerLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        progressView.progressTintColor = NSColor.white.withAlphaComponent(0.85)
        progressView.trackTintColor = NSColor.white.withAlphaComponent(0.12)

        pauseButton.onPress = { [weak self] in self?.onTogglePause?() }
        stopButton.onPress = { [weak self] in self?.onStop?() }
        stopButton.toolTip = "capture.hud_stop".localized
        stopButton.setAccessibilityLabel("capture.hud_stop".localized)

        let root = NSStackView(views: [dotView, timerLabel, subtitleLabel, pauseButton, stopButton])
        root.orientation = .horizontal
        root.alignment = .centerY
        root.distribution = .fill
        root.spacing = 8
        root.setCustomSpacing(12, after: subtitleLabel)
        root.setCustomSpacing(5, after: pauseButton)
        root.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: (Self.height - HudButton.side) / 2)

        for view in [backgroundView, root, progressView] as [NSView] {
            addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        dotView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: Self.height),

            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.height / 2),
            progressView.trailingAnchor.constraint(equalTo: pauseButton.leadingAnchor, constant: -12),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
    }

    private func updateUI() {
        let elapsed = max(0, elapsedSeconds)
        let maxDuration = max(0, maxDurationSeconds)

        if maxDuration > 0 {
            // Limited clip: count down with a progress line.
            timerLabel.stringValue = formatTime(seconds: maxDuration - elapsed)
            progressView.isHidden = false
            progressView.progress = Double(elapsed) / Double(maxDuration)
        } else {
            // Unlimited: count up until the user stops.
            timerLabel.stringValue = formatTime(seconds: elapsed)
            progressView.isHidden = true
        }

        if isPaused {
            subtitleLabel.stringValue = "capture.hud_paused_badge".localized
        } else if qualityText.isEmpty {
            subtitleLabel.stringValue =
                maxDuration > 0 ? "capture.hud_remaining".localized : "capture.hud_recording".localized
        } else {
            subtitleLabel.stringValue = qualityText
        }

        dotView.layer?.backgroundColor = (isPaused ? NSColor.systemOrange : NSColor.systemRed).cgColor
        let pauseTitle = isPaused ? "capture.hud_resume".localized : "capture.hud_pause".localized
        pauseButton.setSymbol(isPaused ? "play.fill" : "pause.fill")
        pauseButton.toolTip = pauseTitle
        pauseButton.setAccessibilityLabel(pauseTitle)

        invalidateIntrinsicContentSize()
    }

    private func formatTime(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Round icon button with hover and pressed states, sized for the HUD pill.
private final class HudButton: NSView {
    static let side: CGFloat = 28

    var onPress: (() -> Void)?

    private let baseColor: NSColor
    private let iconView = NSImageView()
    private var isHovered = false { didSet { refreshBackground() } }
    private var isPressed = false { didSet { refreshBackground() } }

    init(symbolName: String, baseColor: NSColor) {
        self.baseColor = baseColor
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        layer?.cornerRadius = Self.side / 2
        layer?.masksToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)

        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleNone
        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setSymbol(symbolName)
        refreshBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setSymbol(_ name: String) {
        iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .bold))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onPress?()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }

    private func refreshBackground() {
        let fraction: CGFloat = isPressed ? 0.3 : (isHovered ? 0.18 : 0)
        layer?.backgroundColor = (baseColor.blended(withFraction: fraction, of: .white) ?? baseColor).cgColor
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
