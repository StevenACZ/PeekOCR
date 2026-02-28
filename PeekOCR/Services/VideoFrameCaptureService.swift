//
//  VideoFrameCaptureService.swift
//  PeekOCR
//
//  Captures and saves a single frame from a video at a specific timestamp.
//

import AVFoundation
import Foundation

/// Errors that can occur while capturing a still image from a video clip.
enum VideoFrameCaptureError: LocalizedError {
    case invalidTime
    case directoryCreationFailed(path: String, underlying: Error)
    case frameExtractionFailed(underlying: Error)
    case encodingFailed(format: ImageFormat)
    case saveFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidTime:
            return "No se pudo capturar el frame en ese instante."
        case .directoryCreationFailed(let path, _):
            return "No se pudo crear la carpeta de salida: \(path)"
        case .frameExtractionFailed:
            return "No se pudo extraer el frame del video."
        case .encodingFailed(let format):
            return "No se pudo codificar la captura en formato \(format.fileExtension.uppercased())."
        case .saveFailed(let path, _):
            return "No se pudo guardar la captura en: \(path)"
        }
    }
}

/// Service for extracting a frame image from a clip and saving it to disk.
final class VideoFrameCaptureService {
    static let shared = VideoFrameCaptureService()

    private init() {}

    func captureFrame(
        videoURL: URL,
        at seconds: Double,
        outputDirectory: URL,
        format: ImageFormat,
        quality: Double
    ) async throws -> URL {
        guard seconds.isFinite else {
            throw VideoFrameCaptureError.invalidTime
        }
        let safeSeconds = max(0, seconds)

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw VideoFrameCaptureError.directoryCreationFailed(path: outputDirectory.path, underlying: error)
        }

        let outputURL = generateUniqueOutputURL(in: outputDirectory, format: format)

        let data: Data
        do {
            let asset = AVURLAsset(
                url: videoURL,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )
            let duration = try await asset.load(.duration)

            let preferredTimeScale = duration.timescale > 0 ? duration.timescale : 600
            let durationSeconds = duration.seconds
            let captureSeconds: Double
            if durationSeconds.isFinite, durationSeconds > 0 {
                let epsilon = max(1.0 / Double(preferredTimeScale), 0.001)
                captureSeconds = min(safeSeconds, max(durationSeconds - epsilon, 0))
            } else {
                captureSeconds = safeSeconds
            }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let requestedTime = CMTime(seconds: captureSeconds, preferredTimescale: preferredTimeScale)
            let image = try await generator.image(at: requestedTime).image

            guard let encoded = ImageEncodingService.encode(image, format: format, quality: quality) else {
                throw VideoFrameCaptureError.encodingFailed(format: format)
            }
            data = encoded
        } catch let error as VideoFrameCaptureError {
            throw error
        } catch {
            throw VideoFrameCaptureError.frameExtractionFailed(underlying: error)
        }

        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw VideoFrameCaptureError.saveFailed(path: outputURL.path, underlying: error)
        }

        return outputURL
    }

    private func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())
        return "PeekOCR_Frame_\(timestamp)"
    }

    private func generateUniqueOutputURL(in directory: URL, format: ImageFormat) -> URL {
        let baseName = generateFilename()
        var candidate = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(format.fileExtension)
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)_\(counter)")
                .appendingPathExtension(format.fileExtension)
            counter += 1
        }

        return candidate
    }
}
