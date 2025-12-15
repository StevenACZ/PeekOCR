//
//  ScreenshotSettings.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import Combine

/// Settings for screenshot capture functionality
final class ScreenshotSettings: ObservableObject {
    static let shared = ScreenshotSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let saveLocation = "screenshotSaveLocation"
        static let imageFormat = "screenshotImageFormat"
        static let imageQuality = "screenshotImageQuality"
        static let imageScale = "screenshotImageScale"
        static let copyToClipboard = "screenshotCopyToClipboard"
        static let saveToFile = "screenshotSaveToFile"
        static let screenshotHotKeyModifiers = "screenshotHotKeyModifiers"
        static let screenshotHotKeyCode = "screenshotHotKeyCode"
    }
    
    // MARK: - Default Values
    
    struct Defaults {
        static let saveLocation = SaveLocation.desktop
        static let imageFormat = ImageFormat.png
        static let imageQuality: Double = 0.9 // 90% quality for JPG
        static let imageScale: Double = 1.0   // 100% scale
        static let copyToClipboard = true
        static let saveToFile = true
    }
    
    // MARK: - Published Properties
    
    /// Where to save screenshots
    @Published var saveLocation: SaveLocation {
        didSet { defaults.set(saveLocation.rawValue, forKey: Keys.saveLocation) }
    }
    
    /// Custom save path (if saveLocation is .custom)
    @Published var customSavePath: String {
        didSet { defaults.set(customSavePath, forKey: "customScreenshotPath") }
    }
    
    /// Image format (PNG, JPG, etc.)
    @Published var imageFormat: ImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Keys.imageFormat) }
    }
    
    /// Image quality for JPG (0.0 to 1.0)
    @Published var imageQuality: Double {
        didSet { defaults.set(imageQuality, forKey: Keys.imageQuality) }
    }
    
    /// Image scale (0.25 to 1.0)
    @Published var imageScale: Double {
        didSet { defaults.set(imageScale, forKey: Keys.imageScale) }
    }
    
    /// Whether to copy screenshot to clipboard
    @Published var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Keys.copyToClipboard) }
    }
    
    /// Whether to save screenshot to file
    @Published var saveToFile: Bool {
        didSet { defaults.set(saveToFile, forKey: Keys.saveToFile) }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load save location
        if let locationRaw = defaults.string(forKey: Keys.saveLocation),
           let location = SaveLocation(rawValue: locationRaw) {
            self.saveLocation = location
        } else {
            self.saveLocation = Defaults.saveLocation
        }
        
        // Load custom path
        self.customSavePath = defaults.string(forKey: "customScreenshotPath") ?? ""
        
        // Load image format
        if let formatRaw = defaults.string(forKey: Keys.imageFormat),
           let format = ImageFormat(rawValue: formatRaw) {
            self.imageFormat = format
        } else {
            self.imageFormat = Defaults.imageFormat
        }
        
        // Load quality and scale
        let savedQuality = defaults.double(forKey: Keys.imageQuality)
        self.imageQuality = savedQuality > 0 ? savedQuality : Defaults.imageQuality
        
        let savedScale = defaults.double(forKey: Keys.imageScale)
        self.imageScale = savedScale > 0 ? savedScale : Defaults.imageScale
        
        // Load boolean settings
        if defaults.object(forKey: Keys.copyToClipboard) != nil {
            self.copyToClipboard = defaults.bool(forKey: Keys.copyToClipboard)
        } else {
            self.copyToClipboard = Defaults.copyToClipboard
        }
        
        if defaults.object(forKey: Keys.saveToFile) != nil {
            self.saveToFile = defaults.bool(forKey: Keys.saveToFile)
        } else {
            self.saveToFile = Defaults.saveToFile
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get the actual save directory URL
    var saveDirectoryURL: URL {
        switch saveLocation {
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case .pictures:
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        case .custom:
            if !customSavePath.isEmpty {
                return URL(fileURLWithPath: customSavePath)
            }
            // Fallback to desktop
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
    }
}

// MARK: - SaveLocation Enum

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
}

// MARK: - ImageFormat Enum

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "png"
    case jpg = "jpg"
    case tiff = "tiff"
    case heic = "heic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpg: return "JPG"
        case .tiff: return "TIFF"
        case .heic: return "HEIC"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .png: return "Sin pérdida, transparencia"
        case .jpg: return "Comprimido, más ligero"
        case .tiff: return "Alta calidad, profesional"
        case .heic: return "Eficiente, Apple"
        }
    }
}
