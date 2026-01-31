//
//  GifExportOptions.swift
//  PeekOCR
//
//  Export options and presets for GIF clip rendering.
//

import Foundation

/// Preset profiles for GIF export.
enum GifExportProfile: String, CaseIterable, Identifiable {
    case low
    case aiDebug
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Baja"
        case .aiDebug: return "AI Debug"
        case .high: return "Alta"
        }
    }
}

/// Options that control GIF export size, FPS and looping.
struct GifExportOptions: Equatable {
    var profile: GifExportProfile = .high
    var fps: Int = 15
    var maxPixelSize: Int = 1080
    var isLoopEnabled: Bool = true

    mutating func applyProfilePreset(_ profile: GifExportProfile) {
        self.profile = profile
        switch profile {
        case .low:
            fps = 15
            maxPixelSize = 480
        case .aiDebug:
            fps = 1
            maxPixelSize = 1080
        case .high:
            fps = 20
            maxPixelSize = 1080
        }
    }
}
