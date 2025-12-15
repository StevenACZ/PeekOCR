//
//  SaveLocation.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation

/// Represents where screenshots should be saved
enum SaveLocation: String, CaseIterable, Identifiable {
    case desktop = "desktop"
    case downloads = "downloads"
    case documents = "documents"
    case pictures = "pictures"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .desktop: return "Escritorio"
        case .downloads: return "Descargas"
        case .documents: return "Documentos"
        case .pictures: return "Imágenes"
        case .custom: return "Personalizada..."
        }
    }

    var icon: String {
        switch self {
        case .desktop: return "desktopcomputer"
        case .downloads: return "arrow.down.circle"
        case .documents: return "doc.fill"
        case .pictures: return "photo.fill"
        case .custom: return "folder.fill"
        }
    }

    /// Get the actual directory URL for this save location
    func directoryURL(customPath: String = "") -> URL {
        switch self {
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case .pictures:
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        case .custom:
            if !customPath.isEmpty {
                return URL(fileURLWithPath: customPath)
            }
            // Fallback to desktop
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
    }
}
