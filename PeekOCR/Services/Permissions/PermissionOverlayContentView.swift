//
//  PermissionOverlayContentView.swift
//  PeekOCR
//
//  Renders the floating helper shown on top of System Settings.
//

import AppKit

final class PermissionOverlayContentView: NSView {
    static let preferredSize = NSSize(width: 548, height: 170)

    private let onClose: () -> Void

    init(hostApp: PermissionHostApp, permission: AppPermission, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
        translatesAutoresizingMaskIntoConstraints = false
        setup(hostApp: hostApp, permission: permission)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(hostApp: PermissionHostApp, permission: AppPermission) {
        let materialView = NSVisualEffectView()
        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.material = .popover
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 20
        materialView.layer?.masksToBounds = true
        materialView.layer?.borderWidth = 1
        materialView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        addSubview(materialView)

        let tintView = NSView()
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor
        materialView.addSubview(tintView)

        let arrowView = NSImageView()
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)
        arrowView.symbolConfiguration = .init(pointSize: 24, weight: .bold)
        arrowView.contentTintColor = permission.accentColor
        materialView.addSubview(arrowView)

        let titleLabel = NSTextField(labelWithString: permission.overlayTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        materialView.addSubview(titleLabel)

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        materialView.addSubview(closeButton)

        let messageLabel = NSTextField(wrappingLabelWithString: permission.overlayMessage)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        messageLabel.textColor = .secondaryLabelColor
        materialView.addSubview(messageLabel)

        let dragSource = PermissionAppDragSourceView(
            hostApp: hostApp,
            accentColor: permission.accentColor
        )
        materialView.addSubview(dragSource)

        let footnoteLabel = NSTextField(wrappingLabelWithString: permission.overlayFootnote)
        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.font = .systemFont(ofSize: 11, weight: .medium)
        footnoteLabel.textColor = .tertiaryLabelColor
        materialView.addSubview(footnoteLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.preferredSize.width),
            heightAnchor.constraint(equalToConstant: Self.preferredSize.height),

            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintView.leadingAnchor.constraint(equalTo: materialView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: materialView.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: materialView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: materialView.bottomAnchor),

            arrowView.leadingAnchor.constraint(equalTo: materialView.leadingAnchor, constant: 24),
            arrowView.topAnchor.constraint(equalTo: materialView.topAnchor, constant: 18),
            arrowView.widthAnchor.constraint(equalToConstant: 24),
            arrowView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: arrowView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: arrowView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            messageLabel.leadingAnchor.constraint(equalTo: arrowView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -22),
            messageLabel.topAnchor.constraint(equalTo: arrowView.bottomAnchor, constant: 12),

            dragSource.leadingAnchor.constraint(equalTo: materialView.leadingAnchor, constant: 24),
            dragSource.trailingAnchor.constraint(equalTo: materialView.trailingAnchor, constant: -24),
            dragSource.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            dragSource.heightAnchor.constraint(equalToConstant: 56),

            footnoteLabel.leadingAnchor.constraint(equalTo: dragSource.leadingAnchor),
            footnoteLabel.trailingAnchor.constraint(equalTo: dragSource.trailingAnchor),
            footnoteLabel.topAnchor.constraint(equalTo: dragSource.bottomAnchor, constant: 10)
        ])
    }

    @objc
    private func closePressed() {
        onClose()
    }
}
