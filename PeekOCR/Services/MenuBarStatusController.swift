//
//  MenuBarStatusController.swift
//  PeekOCR
//
//  Owns the status item, the menu panel popover, and the settings/about windows.
//

import AppKit
import SwiftUI

/// Controller for the menu bar presence: status button, panel popover, and app windows.
@MainActor
final class MenuBarStatusController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var isPopoverTransitioning = false

    private enum Metrics {
        static let popoverMaxHeight: CGFloat = 680
        static let transitionLockDuration: TimeInterval = 0.18
        static let settingsSize = NSSize(width: 760, height: 560)
    }

    // MARK: - Lifecycle

    func start() {
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = statusImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func statusImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "PeekOCR")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func animateStatusButton(_ button: NSStatusBarButton) {
        button.wantsLayer = true
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 0.86, 1.08, 1.0]
        animation.keyTimes = [0, 0.35, 0.75, 1]
        animation.duration = 0.28
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        button.layer?.add(animation, forKey: "peekOCRStatusPress")
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: makePanelHost())
        self.popover = popover
        refreshPopoverSize()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        guard !isPopoverTransitioning else { return }
        lockPopoverTransition()
        animateStatusButton(button)

        if popover.isShown {
            closePopover()
        } else {
            // Rebuild the root view on every open so permissions and history are current.
            if let hosting = popover.contentViewController as? NSHostingController<MenuBarPanelHost> {
                hosting.rootView = makePanelHost()
            } else {
                popover.contentViewController = NSHostingController(rootView: makePanelHost())
            }
            refreshPopoverSize()
            button.state = .on
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self] in
                self?.refreshPopoverSize()
            }
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        statusItem?.button?.state = .off
    }

    func popoverWillClose(_ notification: Notification) {
        statusItem?.button?.state = .off
    }

    private func lockPopoverTransition() {
        isPopoverTransitioning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.transitionLockDuration) { [weak self] in
            self?.isPopoverTransitioning = false
        }
    }

    private func refreshPopoverSize() {
        guard let popover,
            let hosting = popover.contentViewController as? NSHostingController<MenuBarPanelHost>
        else { return }
        let width = Theme.Layout.panelWidth
        let fitting = hosting.sizeThatFits(in: NSSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(max(ceil(fitting.height), 1), Metrics.popoverMaxHeight)
        popover.contentSize = NSSize(width: width, height: height)
        hosting.view.setFrameSize(popover.contentSize)
        hosting.view.layoutSubtreeIfNeeded()
    }

    private func makePanelHost() -> MenuBarPanelHost {
        MenuBarPanelHost(
            openSettings: { [weak self] in self?.openSettingsWindow() },
            openAbout: { [weak self] in self?.openAboutWindow() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    // MARK: - Windows

    func openSettingsWindow() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.settingsWindow = self.presentSettingsWindow(reusing: self.settingsWindow)
        }
    }

    func openAboutWindow() {
        closePopover()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.aboutWindow = self.presentAboutWindow(reusing: self.aboutWindow)
        }
    }

    private func presentSettingsWindow(reusing window: NSWindow?) -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView())
        let target: NSWindow
        if let window {
            target = window
        } else {
            target = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false)
            target.title = "Configuración de PeekOCR"
            target.titleVisibility = .hidden
            target.titlebarAppearsTransparent = true
            target.toolbarStyle = .unified
            target.isReleasedWhenClosed = false
            target.delegate = self
            target.setFrameAutosaveName("PeekOCRSettingsWindow")
        }
        let wasVisible = target.isVisible
        target.contentViewController = hosting
        // NSHostingController collapses to the view minimum; force the intended size back.
        target.setContentSize(Metrics.settingsSize)
        activate(target, centeringIfNeeded: !wasVisible)
        return target
    }

    private func presentAboutWindow(reusing window: NSWindow?) -> NSWindow {
        let hosting = NSHostingController(rootView: AboutView())
        let target: NSWindow
        if let window {
            target = window
        } else {
            target = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false)
            target.title = "Acerca de PeekOCR"
            target.titleVisibility = .hidden
            target.titlebarAppearsTransparent = true
            target.isReleasedWhenClosed = false
            target.standardWindowButton(.miniaturizeButton)?.isHidden = true
            target.standardWindowButton(.zoomButton)?.isHidden = true
            target.delegate = self
            target.setFrameAutosaveName("PeekOCRAboutWindow")
        }
        let wasVisible = target.isVisible
        target.contentViewController = hosting
        target.setContentSize(hosting.view.fittingSize)
        activate(target, centeringIfNeeded: !wasVisible)
        return target
    }

    private func activate(_ window: NSWindow, centeringIfNeeded shouldCenter: Bool) {
        if shouldCenter {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // Drop the SwiftUI content so no state or timers survive a hidden window.
        window.contentViewController = nil
    }
}
