//
//  AppPermission.swift
//  PeekOCR
//
//  Describes the app permissions supported by PeekOCR.
//

import AppKit
import ApplicationServices
import CoreGraphics

/// Supported permissions that PeekOCR can guide the user through.
enum AppPermission: CaseIterable, Hashable {
    case screenRecording
    case accessibility

    var title: String {
        switch self {
        case .screenRecording:
            return "permissions.screen_recording.title".localized
        case .accessibility:
            return "permissions.accessibility.title".localized
        }
    }

    var summary: String {
        switch self {
        case .screenRecording:
            return "permissions.screen_recording.summary".localized
        case .accessibility:
            return "permissions.accessibility.summary".localized
        }
    }

    var iconName: String {
        switch self {
        case .screenRecording:
            return "rectangle.dashed.badge.record"
        case .accessibility:
            return "accessibility"
        }
    }

    var accentColor: NSColor {
        switch self {
        case .screenRecording:
            return NSColor.systemBlue
        case .accessibility:
            return NSColor.systemOrange
        }
    }

    var overlayTitle: String {
        switch self {
        case .screenRecording:
            return "permissions.screen_recording.overlay_title".localized
        case .accessibility:
            return "permissions.accessibility.overlay_title".localized
        }
    }

    var overlayMessage: String {
        switch self {
        case .screenRecording:
            return "permissions.screen_recording.overlay_message".localized
        case .accessibility:
            return "permissions.accessibility.overlay_message".localized
        }
    }

    var overlayFootnote: String {
        "permissions.overlay.footnote".localized
    }

    private var extensionAnchor: String {
        switch self {
        case .screenRecording:
            return "Privacy_ScreenCapture"
        case .accessibility:
            return "Privacy_Accessibility"
        }
    }

    private var legacyAnchor: String {
        switch self {
        case .screenRecording:
            return "Privacy_ScreenCapture"
        case .accessibility:
            return "Privacy_Accessibility"
        }
    }

    var settingsURLs: [URL] {
        [
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(extensionAnchor)"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(legacyAnchor)"),
        ]
        .compactMap { $0 }
    }

    func isGranted() -> Bool {
        switch self {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        case .accessibility:
            return AXIsProcessTrusted()
        }
    }

}
