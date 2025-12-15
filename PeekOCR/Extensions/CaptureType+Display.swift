//
//  CaptureType+Display.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// Display properties for CaptureType used across the app
extension CaptureType {
    /// The color associated with this capture type
    var displayColor: Color {
        switch self {
        case .text:
            return .blue
        case .qrCode:
            return .purple
        case .screenshot:
            return .green
        }
    }

    /// Localized label for this capture type
    var displayLabel: String {
        switch self {
        case .text:
            return "Texto"
        case .qrCode:
            return "QR"
        case .screenshot:
            return "Captura"
        }
    }
}
