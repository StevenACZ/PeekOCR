//
//  PermissionRequirementsWindowController.swift
//  PeekOCR
//
//  Presents a lightweight modal window describing which permissions are missing.
//

import AppKit
import SwiftUI

/// Window controller that explains pending permissions before the app can continue.
@MainActor
final class PermissionRequirementsWindowController: NSWindowController {
    static let shared = PermissionRequirementsWindowController()

    private let windowSize = CGSize(width: 500, height: 520)
    private var hostingController: NSHostingController<AnyView>?

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        guard !PermissionService.shared.missingPermissions().isEmpty else {
            closeWindow()
            return
        }

        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = createWindow()
        let contentView = PermissionRequirementsView(
            onActivate: { [weak self] permission in
                self?.closeWindow()
                PermissionService.shared.requestInteractively(permission)
            },
            onClose: { [weak self] in
                self?.closeWindow()
            }
        )

        let hostingController = NSHostingController(rootView: AnyView(contentView))
        hostingController.view.frame = CGRect(origin: .zero, size: windowSize)

        window.contentViewController = hostingController
        self.hostingController = hostingController
        self.window = window

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        cleanup()
    }

    private func createWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Permisos requeridos"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.delegate = self
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        return window
    }

    private func cleanup() {
        if let hostingController {
            hostingController.view.removeFromSuperview()
            hostingController.rootView = AnyView(EmptyView())
        }

        if let window {
            window.contentViewController = nil
            window.contentView = nil
        }

        hostingController = nil
        window = nil
    }
}

extension PermissionRequirementsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        cleanup()
    }
}
