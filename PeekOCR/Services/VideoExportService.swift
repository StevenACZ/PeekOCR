//
//  VideoExportService.swift
//  PeekOCR
//
//  Exports a trimmed segment of a video to an MP4 file (no audio).
//

import AVFoundation
import Foundation

/// Errors that can occur during MP4 export.
enum VideoExportError: LocalizedError {
    case invalidTimeRange
    case missingVideoTrack
    case cannotCreateReader(underlying: Error)
    case cannotCreateWriter(underlying: Error)
    case cannotAddWriterInput
    case exportFailed(underlying: Error?)
    case directoryCreationFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "El rango seleccionado no es válido."
        case .missingVideoTrack:
            return "El video no contiene una pista de imagen válida."
        case .cannotCreateReader:
            return "No se pudo preparar la lectura del video."
        case .cannotCreateWriter:
            return "No se pudo crear el archivo de salida."
        case .cannotAddWriterInput:
            return "No se pudo configurar la exportación de video."
        case .exportFailed:
            return "No se pudo exportar el video."
        case .directoryCreationFailed(let path, _):
            return "No se pudo crear la carpeta de salida: \(path)"
        }
    }
}

/// Service for exporting a trimmed video segment as an MP4 (no audio).
final class VideoExportService {
    static let shared = VideoExportService()

    private init() {}

    /// Wraps non-Sendable values for use in @Sendable closures that stay on a controlled queue.
    private struct UncheckedSendableBox<Value>: @unchecked Sendable {
        let value: Value
    }

    func exportVideo(
        videoURL: URL,
        timeRange: CMTimeRange,
        outputDirectory: URL,
        options: VideoExportOptions
    ) async throws -> URL {
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw VideoExportError.directoryCreationFailed(path: outputDirectory.path, underlying: error)
        }

        let outputURL = generateUniqueOutputURL(in: outputDirectory)

        return try await Task.detached(priority: .userInitiated) {
            try await Self.renderVideo(
                videoURL: videoURL,
                timeRange: timeRange,
                outputURL: outputURL,
                options: options
            )
            return outputURL
        }.value
    }

    // MARK: - Private

    private static func renderVideo(
        videoURL: URL,
        timeRange: CMTimeRange,
        outputURL: URL,
        options: VideoExportOptions
    ) async throws {
        let asset = AVURLAsset(url: videoURL)

        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds.isFinite ? duration.seconds : 0
        guard durationSeconds > 0 else { throw VideoExportError.invalidTimeRange }

        let start = max(0, timeRange.start.seconds)
        let end = min(durationSeconds, timeRange.end.seconds)
        guard end > start else { throw VideoExportError.invalidTimeRange }

        let clampedRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = tracks.first else {
            throw VideoExportError.missingVideoTrack
        }

        let nominalFrameRate: Float = (try? await sourceVideoTrack.load(.nominalFrameRate)) ?? 0
        let nominalFps = nominalFrameRate.isFinite && nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        let sourceFps = await estimateSourceFrameRate(asset: asset, track: sourceVideoTrack, timeRange: clampedRange) ?? nominalFps
        let requestedFps = max(1, options.fps)
        let effectiveFps = Int(min(Double(requestedFps), sourceFps.rounded(.down)))

        let (renderSize, transform) = try await computeRenderSizeAndTransform(
            track: sourceVideoTrack,
            maxSize: options.resolution.maxSize
        )

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportError.exportFailed(underlying: nil)
        }

        try compositionVideoTrack.insertTimeRange(clampedRange, of: sourceVideoTrack, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: clampedRange.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(max(1, effectiveFps)))
        videoComposition.instructions = [instruction]

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: composition)
        } catch {
            throw VideoExportError.cannotCreateReader(underlying: error)
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ]
        let readerOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [compositionVideoTrack], videoSettings: outputSettings)
        readerOutput.videoComposition = videoComposition
        readerOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(readerOutput) else {
            throw VideoExportError.cannotCreateReader(underlying: reader.error ?? NSError(domain: "VideoExportService", code: -1))
        }
        reader.add(readerOutput)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw VideoExportError.cannotCreateWriter(underlying: error)
        }

        let videoBitrate = estimatedBitrateBitsPerSecond(
            renderSize: renderSize,
            fps: effectiveFps,
            codec: options.codec
        )

        let writerVideoSettings: [String: Any] = [
            AVVideoCodecKey: options.codec.avVideoCodecType.rawValue,
            AVVideoWidthKey: Int(renderSize.width),
            AVVideoHeightKey: Int(renderSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoExpectedSourceFrameRateKey: effectiveFps,
                AVVideoMaxKeyFrameIntervalKey: max(1, effectiveFps * 2),
            ],
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
        writerInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(writerInput) else {
            throw VideoExportError.cannotAddWriterInput
        }
        writer.add(writerInput)

        guard reader.startReading() else {
            throw VideoExportError.exportFailed(underlying: reader.error)
        }

        guard writer.startWriting() else {
            throw VideoExportError.exportFailed(underlying: writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        let writerInputBox = UncheckedSendableBox(value: writerInput)
        let readerOutputBox = UncheckedSendableBox(value: readerOutput)
        let readerBox = UncheckedSendableBox(value: reader)
        let writerBox = UncheckedSendableBox(value: writer)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "PeekOCR.videoExport.writer")

            let targetFrameDuration = CMTime(value: 1, timescale: Int32(max(1, effectiveFps)))
            var nextAllowed = CMTime.zero
            var frameIndex: Int64 = 0

            writerInputBox.value.requestMediaDataWhenReady(on: queue) {
                let writerInput = writerInputBox.value
                let readerOutput = readerOutputBox.value
                let reader = readerBox.value
                let writer = writerBox.value

                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        if pts < nextAllowed {
                            continue
                        }

                        var timing = CMSampleTimingInfo(
                            duration: targetFrameDuration,
                            presentationTimeStamp: CMTimeMultiply(targetFrameDuration, multiplier: Int32(frameIndex)),
                            decodeTimeStamp: .invalid
                        )

                        var retimed: CMSampleBuffer?
                        let status = CMSampleBufferCreateCopyWithNewTiming(
                            allocator: kCFAllocatorDefault,
                            sampleBuffer: sampleBuffer,
                            sampleTimingEntryCount: 1,
                            sampleTimingArray: &timing,
                            sampleBufferOut: &retimed
                        )

                        guard status == noErr, let outputBuffer = retimed else {
                            writerInput.markAsFinished()
                            reader.cancelReading()
                            writer.cancelWriting()
                            continuation.resume(throwing: VideoExportError.exportFailed(underlying: nil))
                            return
                        }

                        if !writerInput.append(outputBuffer) {
                            writerInput.markAsFinished()
                            reader.cancelReading()
                            writer.cancelWriting()
                            continuation.resume(throwing: VideoExportError.exportFailed(underlying: writer.error))
                            return
                        }

                        frameIndex += 1
                        nextAllowed = pts + targetFrameDuration
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                continuation.resume()
                            } else {
                                continuation.resume(throwing: VideoExportError.exportFailed(underlying: writer.error))
                            }
                        }
                        return
                    }
                }
            }
        }
    }

    private static func computeRenderSizeAndTransform(
        track: AVAssetTrack,
        maxSize: CGSize
    ) async throws -> (CGSize, CGAffineTransform) {
        let (naturalSize, preferredTransform) = try await track.load(.naturalSize, .preferredTransform)

        let naturalRect = CGRect(origin: .zero, size: naturalSize)
        let transformedRect = naturalRect.applying(preferredTransform)
        let orientedSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))

        let scaleX = maxSize.width / max(1, orientedSize.width)
        let scaleY = maxSize.height / max(1, orientedSize.height)
        let scale = min(1, min(scaleX, scaleY))

        var renderSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        renderSize.width = max(2, floor(renderSize.width / 2) * 2)
        renderSize.height = max(2, floor(renderSize.height / 2) * 2)

        var transform = preferredTransform
        transform = transform.concatenating(CGAffineTransform(translationX: -transformedRect.origin.x, y: -transformedRect.origin.y))
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        return (renderSize, transform)
    }

    private static func estimatedBitrateBitsPerSecond(renderSize: CGSize, fps: Int, codec: VideoExportCodec) -> Int {
        let pixels = max(1, renderSize.width * renderSize.height)
        let bitsPerPixelPerFrame: Double = codec == .hevc ? 0.07 : 0.12
        let raw = Double(pixels) * Double(max(1, fps)) * bitsPerPixelPerFrame
        return Int(min(max(raw, 1_000_000), 60_000_000))
    }

    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = dateFormatter.string(from: Date())
        return "PeekOCR_\(timestamp)"
    }

    private func generateUniqueOutputURL(in outputDirectory: URL) -> URL {
        let baseName = generateFilename()
        var candidateURL = outputDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("mp4")
        var counter = 1

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = outputDirectory
                .appendingPathComponent("\(baseName)_\(counter)")
                .appendingPathExtension("mp4")
            counter += 1
        }

        return candidateURL
    }

    private static func estimateSourceFrameRate(asset: AVAsset, track: AVAssetTrack, timeRange: CMTimeRange) async -> Double? {
        do {
            let reader = try AVAssetReader(asset: asset)
            reader.timeRange = timeRange

            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            output.alwaysCopiesSampleData = false

            guard reader.canAdd(output) else { return nil }
            reader.add(output)

            guard reader.startReading() else { return nil }

            var lastTimestamp: Double?
            var deltas: [Double] = []

            while deltas.count < 90, let sample = output.copyNextSampleBuffer() {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                guard timestamp.isFinite else { continue }

                if let last = lastTimestamp {
                    let delta = timestamp - last
                    if delta > 0.001, delta < 0.1 {
                        deltas.append(delta)
                    }
                }
                lastTimestamp = timestamp
            }

            guard deltas.count >= 12 else { return nil }

            let sorted = deltas.sorted()
            let median = sorted[sorted.count / 2]
            guard median > 0 else { return nil }

            let fps = 1.0 / median
            return normalizeEstimatedFps(fps)
        } catch {
            return nil
        }
    }

    private static func normalizeEstimatedFps(_ fps: Double) -> Double? {
        guard fps.isFinite, fps >= 10, fps <= 120 else { return nil }

        let candidates: [Double] = [60.0, 59.94, 30.0, 29.97, 24.0]
        guard let best = candidates.min(by: { abs($0 - fps) < abs($1 - fps) }) else { return nil }

        if abs(best - fps) <= 2.0 {
            return best.rounded()
        }
        return nil
    }
}
