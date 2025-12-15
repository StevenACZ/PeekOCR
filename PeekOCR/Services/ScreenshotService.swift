//
//  ScreenshotService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import UniformTypeIdentifiers

/// Service for saving and processing screenshots
final class ScreenshotService {
    static let shared = ScreenshotService()
    
    private let settings = ScreenshotSettings.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Process and save a captured screenshot
    /// - Parameter image: The captured CGImage
    /// - Returns: URL where the image was saved, or nil if not saved to file
    @discardableResult
    func processScreenshot(_ image: CGImage) async -> URL? {
        // Apply scale if needed
        let processedImage = scaleImage(image, scale: settings.imageScale)
        
        // Copy to clipboard if enabled
        if settings.copyToClipboard {
            copyImageToClipboard(processedImage)
        }
        
        // Save to file if enabled
        var savedURL: URL? = nil
        if settings.saveToFile {
            savedURL = saveImageToFile(processedImage)
        }
        
        return savedURL
    }
    
    /// Copy image to clipboard
    /// - Parameter image: The image to copy
    func copyImageToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
    }
    
    /// Save image to file
    /// - Parameter image: The image to save
    /// - Returns: URL where the image was saved
    func saveImageToFile(_ image: CGImage) -> URL? {
        let directory = settings.saveDirectoryURL
        let filename = generateFilename()
        let fileURL = directory.appendingPathComponent(filename)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Get image data based on format
        guard let imageData = getImageData(from: image, format: settings.imageFormat) else {
            return nil
        }
        
        // Write to file
        do {
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save screenshot: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Scale the image by the given factor
    private func scaleImage(_ image: CGImage, scale: Double) -> CGImage {
        guard scale < 1.0 else { return image }
        
        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)
        
        guard newWidth > 0, newHeight > 0 else { return image }
        
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return image
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage() ?? image
    }
    
    /// Generate a filename for the screenshot
    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        return "PeekOCR_\(timestamp).\(settings.imageFormat.fileExtension)"
    }
    
    /// Convert CGImage to Data in the specified format
    private func getImageData(from image: CGImage, format: ImageFormat) -> Data? {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
            
        case .jpg:
            return bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: settings.imageQuality]
            )
            
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:])
            
        case .heic:
            // HEIC requires macOS 10.13+ and specific handling
            if #available(macOS 10.13, *) {
                return bitmapRep.representation(
                    using: .jpeg2000,
                    properties: [.compressionFactor: settings.imageQuality]
                )
            } else {
                // Fallback to PNG
                return bitmapRep.representation(using: .png, properties: [:])
            }
        }
    }
}
