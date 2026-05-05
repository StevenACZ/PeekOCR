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
            return "Grabar Pantalla"
        case .accessibility:
            return "Accesibilidad"
        }
    }

    var summary: String {
        switch self {
        case .screenRecording:
            return "Necesario para OCR, capturas y clips."
        case .accessibility:
            return "Necesario para atajos globales."
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
            return "Activa Grabar Pantalla"
        case .accessibility:
            return "Activa Accesibilidad"
        }
    }

    var overlayMessage: String {
        switch self {
        case .screenRecording:
            return
                "Si PeekOCR ya aparece en la lista, solo activa el interruptor. Si no aparece todavía, arrástralo desde la tarjeta inferior."
        case .accessibility:
            return "Si PeekOCR ya aparece en la lista, solo habilítalo. Si todavía no está visible, arrástralo desde la tarjeta inferior."
        }
    }

    var overlayFootnote: String {
        "Cuando vuelvas a PeekOCR, actualizaremos este estado automáticamente."
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
