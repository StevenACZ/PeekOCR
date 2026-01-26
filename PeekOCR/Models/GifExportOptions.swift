//
//  GifExportOptions.swift
//  PeekOCR
//
//  Export options and presets for GIF clip rendering.
//

import Foundation

/// Preset quality levels for GIF export.
enum GifExportQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        case .ultra: return "Ultra"
        }
    }
}

/// Options that control GIF export size, FPS and looping.
struct GifExportOptions: Equatable {
    var quality: GifExportQuality = .medium
    var fps: Int = 15
    var maxPixelSize: Int = 720
    var isDitheringEnabled: Bool = true
    var isLoopEnabled: Bool = true

    mutating func applyQualityPreset(_ quality: GifExportQuality) {
        self.quality = quality
        switch quality {
        case .low:
            fps = 12
            maxPixelSize = 480
        case .medium:
            fps = 15
            maxPixelSize = 720
        case .high:
            fps = 24
            maxPixelSize = 1080
        case .ultra:
            fps = 30
            maxPixelSize = 1080
        }
    }
}

