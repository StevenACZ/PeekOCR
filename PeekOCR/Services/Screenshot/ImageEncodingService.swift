//
//  ImageEncodingService.swift
//  PeekOCR
//
//  Converts CGImage to various formats (PNG, JPEG, TIFF, HEIC).
//

import AppKit
import CoreGraphics

/// Encodes CGImage to various image formats with configurable quality
enum ImageEncodingService {
    /// Convert a CGImage to Data in the specified format
    /// - Parameters:
    ///   - image: The source CGImage
    ///   - format: Target image format
    ///   - quality: Compression quality (0.0-1.0) for lossy formats
    /// - Returns: Encoded image data, or nil on failure
    static func encode(_ image: CGImage, format: ImageFormat, quality: Double = 1.0) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        bitmapRep.size = NSSize(width: image.width, height: image.height)

        switch format {
        case .png:
            return encodePNG(bitmapRep)
        case .jpg:
            return encodeJPEG(bitmapRep, quality: quality)
        case .tiff:
            return encodeTIFF(bitmapRep)
        case .heic:
            return encodeHEIC(image, quality: quality)
        }
    }

    // MARK: - Private Encoders

    private static func encodePNG(_ bitmapRep: NSBitmapImageRep) -> Data? {
        bitmapRep.representation(using: .png, properties: [
            .interlaced: false
        ])
    }

    private static func encodeJPEG(_ bitmapRep: NSBitmapImageRep, quality: Double) -> Data? {
        bitmapRep.representation(using: .jpeg, properties: [
            .compressionFactor: quality,
            .progressive: false
        ])
    }

    private static func encodeTIFF(_ bitmapRep: NSBitmapImageRep) -> Data? {
        bitmapRep.representation(using: .tiff, properties: [
            .compressionMethod: NSBitmapImageRep.TIFFCompression.none
        ])
    }

    private static func encodeHEIC(_ image: CGImage, quality: Double) -> Data? {
        if #available(macOS 11.0, *) {
            return createHEICData(from: image, quality: quality)
        } else {
            // Fallback to PNG for older macOS
            let bitmapRep = NSBitmapImageRep(cgImage: image)
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }

    @available(macOS 11.0, *)
    private static func createHEICData(from image: CGImage, quality: Double) -> Data? {
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
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}
