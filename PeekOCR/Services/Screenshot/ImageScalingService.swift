//
//  ImageScalingService.swift
//  PeekOCR
//
//  High-quality image scaling using CGContext with Lanczos interpolation.
//

import CoreGraphics

/// Provides high-quality image scaling operations
enum ImageScalingService {
    /// Scale an image by a given factor with high quality
    /// - Parameters:
    ///   - image: The source CGImage to scale
    ///   - scale: Scale factor (0.0-1.0 for reduction)
    /// - Returns: Scaled image, or original if scaling fails
    static func scaleImage(_ image: CGImage, scale: Double) -> CGImage {
        guard scale < 1.0, scale > 0 else { return image }

        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        guard newWidth > 0, newHeight > 0 else { return image }

        // Use sRGB color space for consistent colors
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
}
