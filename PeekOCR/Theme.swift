//
//  Theme.swift
//  PeekOCR
//
//  Central design tokens shared by the menu bar panel and app windows.
//

import AppKit
import SwiftUI

/// Design tokens for PeekOCR UI surfaces.
enum Theme {
    /// Brand accent, matching the app icon identity.
    static let accent = Color(nsColor: .systemBlue)
    static let nsAccent = NSColor.systemBlue

    /// Brand gradient used by hero artwork.
    static let accentGradient = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    enum Layout {
        static let panelWidth: CGFloat = 320
        static let cornerRadius: CGFloat = 12
    }

    enum Anim {
        static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let easeOut = Animation.easeOut(duration: 0.2)
        static let slide = Animation.easeInOut(duration: 0.35)
    }
}
