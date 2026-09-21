import AppKit
import Combine
import SwiftUI

@MainActor
final class CapturePreviewController: ObservableObject {
    static let shared = CapturePreviewController()

    @Published private(set) var assets: [CaptureClipboardAsset] = []
    @Published private(set) var countdown: Double = 1
    @Published private(set) var countdownDuration: TimeInterval = 0
    @Published private(set) var copied = false

    private var batch = CaptureBatch()
    private var panel: NSPanel?
    private var content: CapturePreviewHostingView?
    private var dismissalTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var deadline: Date?
    private var remaining: TimeInterval = 2
    @Published private(set) var isHovered = false
    @Published private(set) var previewScreenHeight: CGFloat = 1000
    private var suspended = false
    private var presentationID = UUID()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var settingsObserver: AnyCancellable?
    private let pasteboard = NSPasteboard.general

    private init() {
        let currentURLs = Set(pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [])
        Task.detached(priority: .utility) { CaptureClipboardAsset.removeExpiredFiles(excluding: currentURLs) }
        settingsObserver = ScreenshotSettings.shared.$groupedCopy.dropFirst().sink { [weak self] grouped in
            self?.copySelection(grouped: grouped, explicit: false)
        }
    }

    func beginCapture() {
        batch.beginCapture(at: Date(), clipboardChangeCount: pasteboard.changeCount)
        suspended = true
        expiryTask?.cancel()
        hide(animated: false)
    }

    func endCapture() {
        suspended = false
        batch.endCapture()
        scheduleExpiry()
    }

    func receive(_ asset: CaptureClipboardAsset, copyToClipboard: Bool, showPreview: Bool) {
        let continued = batch.append(asset.id, at: Date(), clipboardChangeCount: pasteboard.changeCount)
        if !continued { assets.removeAll() }
        assets.append(asset)
        copied = false
        if copyToClipboard { copySelection(grouped: ScreenshotSettings.shared.groupedCopy, explicit: true) }
        installPasteObservers()
        if showPreview { present() }
        scheduleExpiry()
    }

    func remove(_ id: UUID) {
        let owned = batch.ownsClipboard(pasteboard.changeCount)
        batch.remove(id)
        assets.removeAll { $0.id == id }
        if owned && copied {
            if assets.isEmpty {
                pasteboard.clearContents()
                batch.didCopy(changeCount: pasteboard.changeCount)
            } else {
                copySelection(grouped: ScreenshotSettings.shared.groupedCopy, explicit: false)
            }
        }
        if assets.isEmpty { hide(animated: true) } else { resizePanel() }
    }

    func copy() {
        copySelection(grouped: ScreenshotSettings.shared.groupedCopy, explicit: true)
    }

    func setHovered(_ value: Bool) {
        guard panel?.isVisible == true, isHovered != value else { return }
        isHovered = value
        if value {
            remaining = max(0, deadline?.timeIntervalSinceNow ?? remaining)
            dismissalTask?.cancel()
            countdownDuration = 0
            countdown = min(1, remaining / 2)
            expiryTask?.cancel()
        } else {
            startCountdown(seconds: max(1, remaining))
            scheduleExpiry()
        }
    }

    func dismiss() {
        hide(animated: true)
    }

    private func copySelection(grouped: Bool, explicit: Bool) {
        guard explicit || (copied && batch.ownsClipboard(pasteboard.changeCount)) else { return }
        let ids = Set(batch.copiedIDs(grouped: grouped))
        let selection = assets.filter { ids.contains($0.id) }
        guard CaptureClipboardWriter.write(selection, to: pasteboard) else { return }
        batch.didCopy(changeCount: pasteboard.changeCount)
        copied = true
    }

    private func present() {
        guard !assets.isEmpty else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        previewScreenHeight = screen.visibleFrame.height
        let target = frame(on: screen)
        let isNew = panel == nil || panel?.isVisible == false
        presentationID = UUID()
        if panel == nil {
            let window = NSPanel(contentRect: target, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            let content = CapturePreviewHostingView(rootView: CapturePreviewView(controller: self))
            content.sizingOptions = []
            content.onHover = { [weak self] in self?.setHovered($0) }
            content.frame = CGRect(x: Self.edgeInset, y: 0, width: CapturePreviewLayout.width, height: target.height)
            content.autoresizingMask = [.height]
            let container = NSView(frame: CGRect(origin: .zero, size: target.size))
            container.addSubview(content)
            window.acceptsMouseMovedEvents = true
            window.contentView = container
            panel = window
            self.content = content
        }
        guard let panel, let content else { return }
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if isNew {
            panel.setFrame(target, display: false)
            content.setFrameOrigin(CGPoint(x: reducedMotion ? Self.edgeInset : Self.hiddenX, y: 0))
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducedMotion ? 0.12 : 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            panel.animator().setFrame(target, display: true)
            content.animator().setFrameOrigin(CGPoint(x: Self.edgeInset, y: 0))
            panel.animator().alphaValue = 1
        }
        isHovered = target.contains(NSEvent.mouseLocation)
        remaining = 2
        if !isHovered { startCountdown(seconds: 2) }
    }

    var previewLayout: CapturePreviewLayout { CapturePreviewLayout(screenHeight: previewScreenHeight) }

    private var previewImageSizes: [CGSize] {
        assets.map { CGSize(width: $0.thumbnail.width, height: $0.thumbnail.height) }
    }

    var previewViewportHeight: CGFloat { previewLayout.viewportHeight(for: previewImageSizes) }

    private static let edgeInset: CGFloat = 16
    private static let hiddenX = -CapturePreviewLayout.width

    // The panel stays on its screen and clips the sliding content; moving the window spills onto a neighboring display.
    private func frame(on screen: NSScreen) -> CGRect {
        let layout = CapturePreviewLayout(screenHeight: screen.visibleFrame.height)
        return CGRect(
            x: screen.visibleFrame.minX, y: screen.visibleFrame.minY + 20,
            width: CapturePreviewLayout.width + Self.edgeInset, height: layout.panelHeight(for: previewImageSizes))
    }

    private func resizePanel() {
        guard let panel, let screen = panel.screen else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame(on: screen), display: true)
        }
    }

    private func startCountdown(seconds: TimeInterval) {
        dismissalTask?.cancel()
        remaining = seconds
        deadline = Date().addingTimeInterval(seconds)
        countdownDuration = 0
        countdown = min(1, seconds / 2)
        dismissalTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.countdownDuration = seconds
            self.countdown = 0
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self.hide(animated: true)
        }
    }

    private func hide(animated: Bool) {
        dismissalTask?.cancel()
        dismissalTask = nil
        isHovered = false
        deadline = nil
        scheduleExpiry()
        guard let panel else { return }
        let token = UUID()
        presentationID = token
        guard animated else {
            panel.orderOut(nil)
            self.panel = nil
            content = nil
            return
        }
        let content = content
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = reducedMotion ? 0.12 : 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
                if !reducedMotion {
                    content?.animator().setFrameOrigin(CGPoint(x: Self.hiddenX, y: 0))
                }
            },
            completionHandler: { [self, panel] in
                Task { @MainActor in
                    guard self.presentationID == token else { return }
                    panel.orderOut(nil)
                    self.panel = nil
                    self.content = nil
                }
            })
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard !suspended, !isHovered else { return }
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(CaptureBatch.groupingInterval))
            guard let self, !Task.isCancelled else { return }
            self.assets.removeAll()
            self.batch = CaptureBatch()
            self.removePasteObservers()
        }
    }

    private func installPasteObservers() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.observePaste(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.observePaste(event)
            return event
        }
    }

    private func observePaste(_ event: NSEvent) {
        guard event.keyCode == 9, event.modifierFlags.contains(.command),
            batch.ownsClipboard(pasteboard.changeCount)
        else { return }
        batch.didPaste()
        hide(animated: true)
    }

    private func removePasteObservers() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
