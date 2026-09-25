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
            return NSColor.systemRed
        case .accessibility:
            return NSColor.systemBlue
        }
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
