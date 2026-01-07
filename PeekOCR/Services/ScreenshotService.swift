//
//  ScreenshotService.swift
//  PeekOCR
//
//  Orchestrates screenshot processing, scaling, and saving.
//

import AppKit

/// Service for processing and saving screenshots
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
        let processedImage = settings.imageScale < 1.0
            ? ImageScalingService.scaleImage(image, scale: settings.imageScale)
            : image

        // Copy to clipboard if enabled
        if settings.copyToClipboard {
            copyImageToClipboard(processedImage)
        }

        // Save to file if enabled
        return settings.saveToFile ? saveImageToFile(processedImage) : nil
    }

    /// Copy image to clipboard with maximum quality
    func copyImageToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let nsImage = createHighQualityNSImage(from: image)
        pasteboard.writeObjects([nsImage])
    }

    /// Save image to file with configured format and quality
    func saveImageToFile(_ image: CGImage) -> URL? {
        let directory = settings.saveDirectoryURL
        let filename = generateFilename()
        let fileURL = directory.appendingPathComponent(filename)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Encode image using the service
        guard let imageData = ImageEncodingService.encode(
            image,
            format: settings.imageFormat,
            quality: settings.imageQuality
        ) else {
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
