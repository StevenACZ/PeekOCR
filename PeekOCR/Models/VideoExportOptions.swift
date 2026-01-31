//
//  VideoExportOptions.swift
//  PeekOCR
//
//  Export options and presets for clip video rendering.
//

import AVFoundation
import Foundation

/// Video export max resolution presets (fits within the given bounding box, preserving aspect ratio).
enum VideoExportResolution: String, CaseIterable, Identifiable {
    case p720
    case p1080
    case p1440
    case p2160

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .p720: return "720p"
        case .p1080: return "1080p"
        case .p1440: return "2K"
        case .p2160: return "4K"
        }
    }

    var helpText: String {
        switch self {
        case .p720: return "Máx 1280×720 (mantiene proporción)."
        case .p1080: return "Máx 1920×1080 (mantiene proporción)."
        case .p1440: return "Máx 2560×1440 (mantiene proporción)."
        case .p2160: return "Máx 3840×2160 (mantiene proporción)."
        }
    }

    var maxSize: CGSize {
        switch self {
        case .p720: return CGSize(width: 1280, height: 720)
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p1440: return CGSize(width: 2560, height: 1440)
        case .p2160: return CGSize(width: 3840, height: 2160)
        }
    }
}

/// Video codec options for MP4 export.
enum VideoExportCodec: String, CaseIterable, Identifiable {
    case h264
    case hevc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .hevc: return "HEVC"
        }
    }

    var avVideoCodecType: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        }
    }
}

/// Options that control MP4 export resolution, FPS and codec.
struct VideoExportOptions: Equatable {
    var resolution: VideoExportResolution = .p1080
    var fps: Int = 30
    var codec: VideoExportCodec = .h264
}
