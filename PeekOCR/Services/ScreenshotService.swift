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

    private struct SettingsSnapshot: Sendable {
        let imageScale: Double
        let copyToClipboard: Bool
        let saveToFile: Bool
        let saveDirectoryURL: URL
        let imageFormat: ImageFormat
        let imageQuality: Double
    }

    private struct ProcessedScreenshot: @unchecked Sendable {
        let image: CGImage
        let savedURL: URL?
    }

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

        let snapshot = makeSettingsSnapshot()
        let processed = await Self.processImage(image, using: snapshot)

        if snapshot.copyToClipboard {
            AppLogger.capture.debug("Copying image to clipboard")
            copyImageToClipboard(processed.image)
            AppLogger.capture.info("Image copied to clipboard successfully")
        }

        if let url = processed.savedURL {
            AppLogger.capture.info("Screenshot processing complete - saved to: \(url.lastPathComponent)")
        } else if snapshot.saveToFile {
            AppLogger.capture.warning("Screenshot processing complete - save to file failed")
        } else {
            AppLogger.capture.info("Screenshot processing complete - clipboard only")
        }

        return processed.savedURL
    }

    /// Copy image to clipboard with maximum quality
    func copyImageToClipboard(_ image: CGImage) {
        autoreleasepool {
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
    }

    /// Save image to file with configured format and quality
    func saveImageToFile(_ image: CGImage) -> URL? {
        Self.saveImageToFile(image, using: makeSettingsSnapshot())
    }

    // MARK: - Private Methods

    private func makeSettingsSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            imageScale: settings.imageScale,
            copyToClipboard: settings.copyToClipboard,
            saveToFile: settings.saveToFile,
            saveDirectoryURL: settings.saveDirectoryURL,
            imageFormat: settings.imageFormat,
            imageQuality: settings.imageQuality
        )
    }

    nonisolated private static func processImage(_ image: CGImage, using snapshot: SettingsSnapshot) async -> ProcessedScreenshot {
        await Task.detached(priority: .userInitiated) {
            let processedImage =
                snapshot.imageScale < 1.0
                ? ImageScalingService.scaleImage(image, scale: snapshot.imageScale)
                : image

            let savedURL = snapshot.saveToFile ? Self.saveImageToFile(processedImage, using: snapshot) : nil
            return ProcessedScreenshot(image: processedImage, savedURL: savedURL)
        }.value
    }

    nonisolated private static func saveImageToFile(_ image: CGImage, using snapshot: SettingsSnapshot) -> URL? {
        let directory = snapshot.saveDirectoryURL
        let filename = generateFilename(for: snapshot.imageFormat)
        let fileURL = directory.appendingPathComponent(filename)

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            AppLogger.capture.error("Failed to create directory: \(directory.path) - \(error.localizedDescription)")
            return nil
        }

        // Encode image using the service
        guard
            let imageData = ImageEncodingService.encode(
                image,
                format: snapshot.imageFormat,
                quality: snapshot.imageQuality
            )
        else {
            AppLogger.capture.error(
                "Image encoding failed - format: \(snapshot.imageFormat.fileExtension), quality: \(snapshot.imageQuality)")
            return nil
        }

        // Write to file
        do {
            try imageData.write(to: fileURL, options: .atomic)
            AppLogger.capture.info("Screenshot saved: \(filename) (\(imageData.count) bytes)")
            return fileURL
        } catch {
            AppLogger.capture.error("Failed to write file: \(fileURL.path) - \(error.localizedDescription)")
            return nil
        }
    }

    private func createHighQualityNSImage(from cgImage: CGImage) -> NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return nsImage
    }

    nonisolated private static func generateFilename(for format: ImageFormat) -> String {
        let timestamp = AppDateFormatters.filenameTimestamp()
        return "PeekOCR_\(timestamp).\(format.fileExtension)"
    }
}
