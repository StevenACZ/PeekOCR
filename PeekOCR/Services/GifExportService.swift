//
//  GifExportService.swift
//  PeekOCR
//
//  Exports a trimmed segment of a video to an optimized animated GIF.
//

import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Errors that can occur during GIF export.
enum GifExportError: LocalizedError {
    case invalidTimeRange
    case cannotCreateDestination
    case cannotFinalize
    case cannotLoadDuration
    case frameExtractionFailed(underlying: Error)
    case directoryCreationFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "El rango seleccionado no es válido."
        case .cannotCreateDestination:
            return "No se pudo crear el archivo GIF de salida."
        case .cannotFinalize:
            return "No se pudo finalizar el archivo GIF."
        case .cannotLoadDuration:
            return "No se pudo leer la duración del video."
        case .frameExtractionFailed:
            return "No se pudieron extraer los fotogramas del video."
        case .directoryCreationFailed(let path, _):
            return "No se pudo crear la carpeta de salida: \(path)"
        }
    }
}

/// Service for exporting a trimmed video segment as a GIF.
final class GifExportService {
    static let shared = GifExportService()

    private init() {}

    /// Export a GIF from the given video and time range into the output directory.
    func exportGif(
        videoURL: URL,
        timeRange: CMTimeRange,
        outputDirectory: URL,
        options: GifExportOptions
    ) async throws -> URL {
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw GifExportError.directoryCreationFailed(path: outputDirectory.path, underlying: error)
        }

        let outputURL = outputDirectory
            .appendingPathComponent(generateFilename())
            .appendingPathExtension("gif")

        let loopCount = options.isLoopEnabled ? 0 : 1
        let preset = GifExportPreset(
            fps: max(1, options.fps),
            maxPixelSize: max(16, options.maxPixelSize),
            loopCount: loopCount
        )

        return try await Task.detached(priority: .userInitiated) {
            try await Self.renderGif(
                videoURL: videoURL,
                timeRange: timeRange,
                preset: preset,
                outputURL: outputURL
            )
            return outputURL
        }.value
    }

    // MARK: - Private

    private struct GifExportPreset {
        let fps: Int
        let maxPixelSize: Int
        let loopCount: Int
    }

    private static func renderGif(
        videoURL: URL,
        timeRange: CMTimeRange,
        preset: GifExportPreset,
        outputURL: URL
    ) async throws {
        let asset = AVURLAsset(url: videoURL)

        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds.isFinite ? duration.seconds : 0
        guard durationSeconds > 0 else { throw GifExportError.cannotLoadDuration }

        let start = max(0, timeRange.start.seconds)
        let end = min(durationSeconds, timeRange.end.seconds)

        guard end > start else {
            throw GifExportError.invalidTimeRange
        }

        let clipDuration = end - start
        let fps = max(1, preset.fps)
        let frameCount = max(1, Int(ceil(clipDuration * Double(fps))))
        let delayTime = 1.0 / Double(fps)

        let times: [NSValue] = (0..<frameCount).compactMap { index in
            let seconds = start + (Double(index) / Double(fps))
            guard seconds <= end else { return nil }
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            return NSValue(time: time)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            times.count,
            nil
        ) else {
            throw GifExportError.cannotCreateDestination
        }

        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: preset.loopCount,
            ],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: preset.maxPixelSize, height: preset.maxPixelSize)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        for value in times {
            let time = value.timeValue
            do {
                var actual = CMTime.zero
                let image = try generator.copyCGImage(at: time, actualTime: &actual)

                let frameProperties: [CFString: Any] = [
                    kCGImagePropertyGIFDictionary: [
                        kCGImagePropertyGIFDelayTime: delayTime,
                        kCGImagePropertyGIFUnclampedDelayTime: delayTime,
                    ],
                ]

                CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            } catch {
                throw GifExportError.frameExtractionFailed(underlying: error)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GifExportError.cannotFinalize
        }
    }

    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "PeekOCR_\(timestamp)"
    }
}
