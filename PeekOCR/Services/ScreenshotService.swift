//
//  ScreenshotService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import UniformTypeIdentifiers
import CoreGraphics

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
        // Apply scale if needed (only if less than 100%)
        let processedImage: CGImage
        if settings.imageScale < 1.0 {
            processedImage = scaleImage(image, scale: settings.imageScale)
        } else {
            processedImage = image
        }
        
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
    
    /// Copy image to clipboard with maximum quality
    /// - Parameter image: The image to copy
    func copyImageToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Create high-quality NSImage
        let nsImage = createHighQualityNSImage(from: image)
        pasteboard.writeObjects([nsImage])
    }
    
    /// Save image to file with maximum quality
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
    
    /// Create high quality NSImage from CGImage
    private func createHighQualityNSImage(from cgImage: CGImage) -> NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(size: size)
        
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        
        return nsImage
    }
    
    /// Scale the image by the given factor with high quality
    private func scaleImage(_ image: CGImage, scale: Double) -> CGImage {
        guard scale < 1.0, scale > 0 else { return image }
        
        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)
        
        guard newWidth > 0, newHeight > 0 else { return image }
        
        // Use high quality scaling with proper color space
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        
        // Create context with proper settings for high quality
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        // Set high quality interpolation
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        
        // Draw with high quality
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
    
    /// Convert CGImage to Data in the specified format with maximum quality
    private func getImageData(from image: CGImage, format: ImageFormat) -> Data? {
        // Create bitmap representation directly from CGImage for best quality
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        bitmapRep.size = NSSize(width: image.width, height: image.height)
        
        switch format {
        case .png:
            // PNG is lossless - maximum quality
            return bitmapRep.representation(using: .png, properties: [
                .interlaced: false
            ])
            
        case .jpg:
            // JPG with user-defined quality
            return bitmapRep.representation(using: .jpeg, properties: [
                .compressionFactor: settings.imageQuality,
                .progressive: false
            ])
            
        case .tiff:
            // TIFF is lossless
            return bitmapRep.representation(using: .tiff, properties: [
                .compressionMethod: NSBitmapImageRep.TIFFCompression.none
            ])
            
        case .heic:
            // Use ImageIO for proper HEIC encoding
            if #available(macOS 11.0, *) {
                return createHEICData(from: image)
            } else {
                // Fallback to PNG for older macOS
                return bitmapRep.representation(using: .png, properties: [:])
            }
        }
    }
    
    /// Create HEIC data using ImageIO for proper encoding
    @available(macOS 11.0, *)
    private func createHEICData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.heic" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: settings.imageQuality
        ]
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return data as Data
    }
}
