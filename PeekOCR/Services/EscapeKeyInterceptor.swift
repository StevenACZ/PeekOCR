import CoreGraphics
import os

/// Claims Escape at the HID level while a capture overlay is up. Apps that
/// register Escape as a Carbon hotkey (e.g. a dictation app cancelling its
/// recording) would otherwise consume it before the overlay sees it.
@MainActor
final class EscapeKeyInterceptor {
    private static let escapeKeyCode: Int64 = 53
    private static let modifierFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

    private let onEscape: () -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isEscapeDown = false
    private var stopsOnRelease = false

    init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    func start() {
        stopsOnRelease = false
        guard tap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        let retained = Unmanaged.passRetained(self)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    guard let userInfo else { return Unmanaged.passUnretained(event) }
                    let interceptor = Unmanaged<EscapeKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    let consume = MainActor.assumeIsolated {
                        interceptor.shouldConsume(type: type, keyCode: keyCode, flags: flags)
                    }
                    return consume ? nil : Unmanaged.passUnretained(event)
                },
                userInfo: retained.toOpaque()
            )
        else {
            retained.release()
            AppLogger.capture.warning("Escape interceptor unavailable; overlay keeps window key handling")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        isEscapeDown = false
    }

    /// Waits for the Escape press in flight to be released, so its autorepeat
    /// and key-up never reach the app underneath.
    func stop() {
        if isEscapeDown {
            stopsOnRelease = true
        } else {
            invalidate()
        }
    }

    private func shouldConsume(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown, .keyUp:
            guard keyCode == Self.escapeKeyCode else { return false }
        default:
            return false
        }

        if type == .keyUp {
            guard isEscapeDown else { return false }
            isEscapeDown = false
            if stopsOnRelease { invalidate() }
            return true
        }

        if isEscapeDown { return true }
        guard flags.intersection(Self.modifierFlags).isEmpty else { return false }
        isEscapeDown = true
        Task { @MainActor in self.onEscape() }
        return true
    }

    private func invalidate() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        isEscapeDown = false
        stopsOnRelease = false
        Unmanaged.passUnretained(self).release()
    }
}
