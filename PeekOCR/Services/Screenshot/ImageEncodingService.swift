//
//  ImageEncodingService.swift
//  PeekOCR
//
//  Converts CGImage to various formats (PNG, JPEG, TIFF, HEIC).
//

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Encodes CGImage to various image formats with configurable quality
enum ImageEncodingService {
    /// Convert a CGImage to Data in the specified format
    /// - Parameters:
    ///   - image: The source CGImage
    ///   - format: Target image format
    ///   - quality: Compression quality (0.0-1.0) for lossy formats
    /// - Returns: Encoded image data, or nil on failure
    nonisolated static func encode(_ image: CGImage, format: ImageFormat, quality: Double = 1.0) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, properties(for: format, quality: quality) as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    // MARK: - Private Helpers

    nonisolated private static func properties(for format: ImageFormat, quality: Double) -> [CFString: Any] {
        switch format {
        case .png:
            return [
                kCGImagePropertyPNGDictionary: [
                    kCGImagePropertyPNGInterlaceType: 0,
                ],
            ]
        case .jpg:
            return [
                kCGImageDestinationLossyCompressionQuality: quality,
                kCGImagePropertyJFIFDictionary: [
                    kCGImagePropertyJFIFIsProgressive: false,
                ],
            ]
        case .tiff:
            return [
                kCGImagePropertyTIFFDictionary: [
                    kCGImagePropertyTIFFCompression: 1,
                ],
            ]
        case .heic:
            return [
                kCGImageDestinationLossyCompressionQuality: quality,
            ]
        }
    }
}

private extension ImageFormat {
    nonisolated var utType: UTType {
        switch self {
        case .png:
            return .png
        case .jpg:
            return .jpeg
        case .tiff:
            return .tiff
        case .heic:
            if #available(macOS 11.0, *) {
                return .heic
            } else {
                return .png
            }
        }
    }
}
