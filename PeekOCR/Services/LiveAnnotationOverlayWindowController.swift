import AppKit
import Carbon
import os

@MainActor
final class LiveAnnotationOverlayWindowController: NSWindowController {
    private struct Overlay {
        let window: NSWindow
        let view: LiveAnnotationOverlayView
    }

    private var overlays: [CGDirectDisplayID: Overlay] = [:]
    private var activeDisplayID: CGDirectDisplayID?
    private var quickSelectEventTap: CFMachPort?
    private var quickSelectRunLoopSource: CFRunLoopSource?
    private var quickSelectHotKeyRefs: [EventHotKeyRef] = []
    private var quickSelectHotKeyEventHandler: EventHandlerRef?
    private var continuation: CheckedContinuation<(selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])?, Never>?

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func runSession(
        mode: LiveAnnotationOverlayView.OverlayMode = .annotate,
        frozenImages: [CGDirectDisplayID: CGImage] = [:]
    ) async -> (selectionRect: CGRect, screen: NSScreen, annotations: [LiveAnnotation])? {
        let screens = DisplayEnumerator.activeScreens()
        guard !screens.isEmpty else { return nil }

        overlays = [:]
        activeDisplayID = nil

        for (displayID, screen) in screens {
            let overlay = makeOverlay(
                for: screen,
                displayID: displayID,
                mode: mode,
                frozenImage: frozenImages[displayID]
            )
            overlays[displayID] = overlay
            overlay.window.alphaValue = 0
        }

        let usesGlobalQuickSelectEvents = mode == .quickSelect && installQuickSelectEventTap()
        if usesGlobalQuickSelectEvents {
            for overlay in overlays.values {
                overlay.window.ignoresMouseEvents = true
            }
        } else if mode == .quickSelect {
            installQuickSelectKeyboardHotKeys()
        }

        for overlay in overlays.values {
            // The app is usually inactive when the hotkey fires; orderFrontRegardless
            // is the only call that brings the window up without waiting for activation.
            overlay.window.orderFrontRegardless()
        }

        // Pick the overlay under the cursor. Annotate makes this key for keyboard
        // shortcuts; quick select stays non-activating and mouse-driven.
        let mouseLocation = NSEvent.mouseLocation
        let primaryOverlay =
            overlays.values.first { $0.window.frame.contains(mouseLocation) }
            ?? overlays.values.first
        self.window = primaryOverlay?.window

        if mode == .annotate, let primaryOverlay {
            NSApp.activate(ignoringOtherApps: true)
            primaryOverlay.window.makeKeyAndOrderFront(nil)
            primaryOverlay.window.makeFirstResponder(primaryOverlay.view)
        }
        NSCursor.crosshair.set()

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.15
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
        for overlay in overlays.values {
            overlay.window.animator().alphaValue = 1
        }
        NSAnimationContext.endGrouping()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Cancel an in-flight session programmatically (e.g. the clip hotkey
    /// fired again while the user was still selecting the region).
    func cancelSession() {
        finish(with: nil)
    }

    // MARK: - Private

    private func makeOverlay(
        for screen: NSScreen,
        displayID: CGDirectDisplayID,
        mode: LiveAnnotationOverlayView.OverlayMode,
        frozenImage: CGImage?
    ) -> Overlay {
        let window = makeWindow(for: mode, frame: screen.frame)
        // Force global-coordinate frame: passing `screen:` to the initializer
        // makes AppKit treat contentRect.origin as screen-relative and double it.
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.ignoresMouseEvents = false

        let view = LiveAnnotationOverlayView(screen: screen, mode: mode)
        view.frozenBackgroundImage = frozenImage
        view.resetState()
        view.onCancel = { [weak self] in
            self?.finish(with: nil)
        }
        view.onComplete = { [weak self] selectionRect, completedScreen, annotations in
            self?.finish(with: (selectionRect, completedScreen, annotations))
        }
        view.onActivate = { [weak self] in
            self?.handleActivation(displayID: displayID)
        }

        window.contentView = view
        view.frame = window.contentView?.bounds ?? .zero
        view.autoresizingMask = [.width, .height]

        return Overlay(window: window, view: view)
    }

    private func makeWindow(for mode: LiveAnnotationOverlayView.OverlayMode, frame: CGRect) -> NSWindow {
        switch mode {
        case .annotate:
            return LiveAnnotationOverlayWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
        case .quickSelect:
            let panel = LiveAnnotationQuickSelectOverlayPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.hidesOnDeactivate = false
            return panel
        }
    }

    private func handleActivation(displayID: CGDirectDisplayID) {
        guard activeDisplayID == nil else { return }
        activeDisplayID = displayID
        for (otherID, overlay) in overlays where otherID != displayID {
            overlay.window.orderOut(nil)
        }
    }

    private func finish(with result: (CGRect, NSScreen, [LiveAnnotation])?) {
        uninstallQuickSelectEventTap()
        uninstallQuickSelectKeyboardHotKeys()
        for overlay in overlays.values {
            overlay.window.orderOut(nil)
        }
        overlays.removeAll()
        activeDisplayID = nil
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    private enum QuickSelectMousePhase {
        case down
        case dragged
        case up
    }

    private func installQuickSelectEventTap() -> Bool {
        uninstallQuickSelectEventTap()

        let eventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { _, type, event, userInfo in
                    guard let userInfo else {
                        return Unmanaged.passUnretained(event)
                    }

                    let controller = Unmanaged<LiveAnnotationOverlayWindowController>
                        .fromOpaque(userInfo)
                        .takeUnretainedValue()

                    switch type {
                    case .tapDisabledByTimeout, .tapDisabledByUserInput:
                        Task { @MainActor in
                            controller.reenableQuickSelectEventTap()
                        }
                        return Unmanaged.passUnretained(event)
                    case .leftMouseDown:
                        Task { @MainActor in
                            controller.handleQuickSelectMouseEvent(.down)
                        }
                        return nil
                    case .leftMouseDragged:
                        Task { @MainActor in
                            controller.handleQuickSelectMouseEvent(.dragged)
                        }
                        return nil
                    case .leftMouseUp:
                        Task { @MainActor in
                            controller.handleQuickSelectMouseEvent(.up)
                        }
                        return nil
                    case .keyDown:
                        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                        switch keyCode {
                        case 49:
                            Task { @MainActor in
                                controller.completeQuickSelectFullScreen()
                            }
                            return nil
                        case 53:
                            Task { @MainActor in
                                controller.finish(with: nil)
                            }
                            return nil
                        default:
                            return Unmanaged.passUnretained(event)
                        }
                    default:
                        return Unmanaged.passUnretained(event)
                    }
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            AppLogger.capture.warning("Quick-select event tap unavailable; falling back to panel mouse events")
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            AppLogger.capture.warning("Quick-select event tap source unavailable; falling back to panel mouse events")
            return false
        }

        quickSelectEventTap = tap
        quickSelectRunLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func uninstallQuickSelectEventTap() {
        if let runLoopSource = quickSelectRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            quickSelectRunLoopSource = nil
        }

        if let tap = quickSelectEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            quickSelectEventTap = nil
        }
    }

    private func reenableQuickSelectEventTap() {
        guard let quickSelectEventTap else { return }
        CGEvent.tapEnable(tap: quickSelectEventTap, enable: true)
    }

    private func handleQuickSelectMouseEvent(_ phase: QuickSelectMousePhase) {
        let point = NSEvent.mouseLocation

        switch phase {
        case .down:
            quickSelectOverlay(at: point)?.view.beginQuickSelection(at: point)
        case .dragged:
            activeQuickSelectOverlay(at: point)?.view.updateQuickSelection(at: point)
        case .up:
            activeQuickSelectOverlay(at: point)?.view.finishQuickSelection()
        }
    }

    private func completeQuickSelectFullScreen() {
        quickSelectOverlay(at: NSEvent.mouseLocation)?.view.completeQuickSelectionWithFullScreen()
    }

    private func installQuickSelectKeyboardHotKeys() {
        uninstallQuickSelectKeyboardHotKeys()

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard hotKeyID.signature == QuickSelectKeyboardHotKey.signature, let userData else {
                return OSStatus(eventNotHandledErr)
            }

            let controller = Unmanaged<LiveAnnotationOverlayWindowController>
                .fromOpaque(userData)
                .takeUnretainedValue()
            Task { @MainActor in
                switch hotKeyID.id {
                case QuickSelectKeyboardHotKey.escapeID:
                    controller.finish(with: nil)
                case QuickSelectKeyboardHotKey.spaceID:
                    controller.completeQuickSelectFullScreen()
                default:
                    break
                }
            }

            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &quickSelectHotKeyEventHandler
        )
        guard installStatus == noErr else {
            AppLogger.capture.warning("Quick-select keyboard hotkey handler unavailable (status=\(installStatus))")
            return
        }

        registerQuickSelectKeyboardHotKey(keyCode: UInt32(kVK_Escape), id: QuickSelectKeyboardHotKey.escapeID)
        registerQuickSelectKeyboardHotKey(keyCode: UInt32(kVK_Space), id: QuickSelectKeyboardHotKey.spaceID)
    }

    private func registerQuickSelectKeyboardHotKey(keyCode: UInt32, id: UInt32) {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            0,
            EventHotKeyID(signature: QuickSelectKeyboardHotKey.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            AppLogger.capture.warning("Quick-select keyboard hotkey \(id) unavailable (status=\(status))")
            return
        }

        quickSelectHotKeyRefs.append(ref)
    }

    private func uninstallQuickSelectKeyboardHotKeys() {
        for ref in quickSelectHotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        quickSelectHotKeyRefs.removeAll()

        if let quickSelectHotKeyEventHandler {
            RemoveEventHandler(quickSelectHotKeyEventHandler)
            self.quickSelectHotKeyEventHandler = nil
        }
    }

    private func quickSelectOverlay(at point: CGPoint) -> Overlay? {
        if let active = activeQuickSelectOverlay(at: point) {
            return active
        }

        return overlays.first { _, overlay in
            overlay.window.frame.contains(point)
        }?.value
    }

    private func activeQuickSelectOverlay(at point: CGPoint) -> Overlay? {
        if let activeDisplayID, let overlay = overlays[activeDisplayID] {
            return overlay
        }

        return overlays.values.first { overlay in
            if case .none = overlay.view.interaction {
                return overlay.window.frame.contains(point)
            }

            return true
        }
    }
}

private final class LiveAnnotationOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class LiveAnnotationQuickSelectOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private enum QuickSelectKeyboardHotKey {
    static let signature: OSType = 0x504B514B  // "PKQK"
    static let escapeID: UInt32 = 1
    static let spaceID: UInt32 = 2
}
