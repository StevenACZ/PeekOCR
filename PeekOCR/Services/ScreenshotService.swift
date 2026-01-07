//
//  ScreenshotService.swift
//  PeekOCR
//
//  Orchestrates screenshot processing, scaling, and saving.
//

import AppKit
import os

// MARK: - Screenshot Errors

/// Errors that can occur during screenshot processing
enum ScreenshotError: Error, CustomStringConvertible {
    case encodingFailed(format: ImageFormat)
    case directoryCreationFailed(path: String, underlyingError: Error)
    case saveFailed(path: String, underlyingError: Error)
    case invalidImage

    var description: String {
        switch self {
        case .encodingFailed(let format):
            return "Failed to encode image as \(format.fileExtension)"
        case .directoryCreationFailed(let path, let error):
            return "Failed to create directory at \(path): \(error.localizedDescription)"
        case .saveFailed(let path, let error):
            return "Failed to save screenshot to \(path): \(error.localizedDescription)"
        case .invalidImage:
            return "Invalid or corrupted image data"
        }
    }
}

/// Service for processing and saving screenshots
final class ScreenshotService {
    static let shared = ScreenshotService()

    private let settings = ScreenshotSettings.shared

    // MARK: - Initialization

    private init() {
        AppLogger.capture.debug("ScreenshotService initialized")
    }

    // MARK: - Public Methods

    /// Process and save a captured screenshot
    /// - Parameter image: The captured CGImage
    /// - Returns: URL where the image was saved, or nil if not saved to file
    @discardableResult
    func processScreenshot(_ image: CGImage) async -> URL? {
        AppLogger.capture.info("Processing screenshot - dimensions: \(image.width)x\(image.height)")

        // Apply scale if needed
        let processedImage: CGImage
        if settings.imageScale < 1.0 {
            AppLogger.capture.debug("Applying scale factor: \(self.settings.imageScale)")
            processedImage = ImageScalingService.scaleImage(image, scale: settings.imageScale)
        } else {
            processedImage = image
        }

        // Copy to clipboard if enabled
        if settings.copyToClipboard {
            AppLogger.capture.debug("Copying image to clipboard")
            copyImageToClipboard(processedImage)
            AppLogger.capture.info("Image copied to clipboard successfully")
        }

        // Save to file if enabled
        if settings.saveToFile {
            AppLogger.capture.debug("Save to file enabled, attempting to save")
            let result = saveImageToFile(processedImage)
            if let url = result {
                AppLogger.capture.info("Screenshot processing complete - saved to: \(url.lastPathComponent)")
            } else {
                AppLogger.capture.warning("Screenshot processing complete - save to file failed")
            }
            return result
        }

        AppLogger.capture.info("Screenshot processing complete - clipboard only")
        return nil
    }

    /// Copy image to clipboard with maximum quality
    func copyImageToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let nsImage = createHighQualityNSImage(from: image)
        let success = pasteboard.writeObjects([nsImage])

        if success {
            AppLogger.capture.debug("Clipboard write successful")
        } else {
            AppLogger.capture.error("Clipboard write failed")
        }
    }

    /// Save image to file with configured format and quality
    func saveImageToFile(_ image: CGImage) -> URL? {
        let directory = settings.saveDirectoryURL
        let filename = generateFilename()
        let fileURL = directory.appendingPathComponent(filename)

        AppLogger.capture.debug("Attempting to save to: \(fileURL.path)")

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            AppLogger.capture.debug("Directory verified/created: \(directory.path)")
        } catch {
            AppLogger.capture.error("Failed to create directory: \(directory.path) - \(error.localizedDescription)")
            return nil
        }

        // Encode image using the service
        guard let imageData = ImageEncodingService.encode(
            image,
            format: settings.imageFormat,
            quality: settings.imageQuality
        ) else {
            AppLogger.capture.error("Image encoding failed - format: \(self.settings.imageFormat.fileExtension), quality: \(self.settings.imageQuality)")
            return nil
        }

        AppLogger.capture.debug("Image encoded successfully - size: \(imageData.count) bytes, format: \(self.settings.imageFormat.fileExtension)")

        // Write to file
        do {
            try imageData.write(to: fileURL)
            AppLogger.capture.info("Screenshot saved: \(filename) (\(imageData.count) bytes)")
            return fileURL
        } catch {
            AppLogger.capture.error("Failed to write file: \(fileURL.path) - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func createHighQualityNSImage(from cgImage: CGImage) -> NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return nsImage
    }

    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "PeekOCR_\(timestamp).\(settings.imageFormat.fileExtension)"
    }
}
