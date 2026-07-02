//
//  ImageFormat.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation

/// Supported image formats for screenshot export
enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "png"
    case jpg = "jpg"
    case tiff = "tiff"
    case heic = "heic"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpg: return "JPG"
        case .tiff: return "TIFF"
        case .heic: return "HEIC"
        }
    }

    nonisolated var fileExtension: String {
        return rawValue
    }

    nonisolated var description: String {
        switch self {
        case .png: return "settings.captures.format_png_desc".localized
        case .jpg: return "settings.captures.format_jpg_desc".localized
        case .tiff: return "settings.captures.format_tiff_desc".localized
        case .heic: return "settings.captures.format_heic_desc".localized
        }
    }
}
