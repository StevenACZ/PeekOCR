//
//  VideoExportService.swift
//  PeekOCR
//
//  Exports a trimmed segment of a video to an MP4 file, keeping any
//  recorded system-audio track.
//

import AVFoundation
import Foundation
import os

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

/// Service for exporting a trimmed video segment as an MP4 (audio preserved when present).
final class VideoExportService {
    static let shared = VideoExportService()

    private init() {}

    /// Wraps non-Sendable values for use in @Sendable closures that stay on a controlled queue.
    private struct UncheckedSendableBox<Value>: @unchecked Sendable {
        let value: Value
    }

    /// Serializes the writer-input pumps (video + optional audio) and the
    /// writer finalization. All mutable state is only touched on `queue`.
    private final class ExportPumpCoordinator: @unchecked Sendable {
        let queue = DispatchQueue(label: "PeekOCR.videoExport.writer")

        private let reader: AVAssetReader
        private let writer: AVAssetWriter
        private let continuation: CheckedContinuation<Void, Error>
        private let effectiveFps: Int
        private let renderSize: CGSize
        private let exportStartedAt: Date
        private let outputURL: URL

        private var pendingInputs: Int
        private var didResume = false
        private var appendedFrames: Int64 = 0
        private var skippedFrames: Int64 = 0

        init(
            reader: AVAssetReader,
            writer: AVAssetWriter,
            pendingInputs: Int,
            effectiveFps: Int,
            renderSize: CGSize,
            exportStartedAt: Date,
            outputURL: URL,
            continuation: CheckedContinuation<Void, Error>
        ) {
            self.reader = reader
            self.writer = writer
            self.pendingInputs = pendingInputs
            self.effectiveFps = effectiveFps
            self.renderSize = renderSize
            self.exportStartedAt = exportStartedAt
            self.outputURL = outputURL
            self.continuation = continuation
        }

        /// On `queue`.
        var isFinished: Bool { didResume }

        /// On `queue`.
        func abort(_ error: Error) {
            reader.cancelReading()
            writer.cancelWriting()
            resumeOnce(throwing: error)
        }

        /// On `queue`.
        func finishVideoInput(appendedFrames: Int64, skippedFrames: Int64) {
            self.appendedFrames = appendedFrames
            self.skippedFrames = skippedFrames
            inputFinished()
        }

        /// On `queue`.
        func inputFinished() {
            pendingInputs -= 1
            guard pendingInputs == 0, !didResume else { return }
            writer.finishWriting {
                self.queue.async {
                    self.handleWriterFinished()
                }
            }
        }

        private func handleWriterFinished() {
            if writer.status == .completed {
                let elapsed = Date().timeIntervalSince(exportStartedAt)
                let outputBytes = VideoExportService.fileSize(at: outputURL)
                AppLogger.capture.info(
                    "Video export completed - frames: \(self.appendedFrames), skipped: \(self.skippedFrames), fps: \(self.effectiveFps), renderSize: \(Int(self.renderSize.width))x\(Int(self.renderSize.height)), output: \(outputBytes) bytes, elapsed: \(String(format: "%.2f", elapsed))s"
                )
                resumeOnce(throwing: nil)
            } else {
                resumeOnce(throwing: VideoExportError.exportFailed(underlying: writer.error))
            }
        }

        private func resumeOnce(throwing error: Error?) {
            guard !didResume else { return }
            didResume = true
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
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
            do {
                try await Self.renderVideo(
                    videoURL: videoURL,
                    timeRange: timeRange,
                    outputURL: outputURL,
                    options: options
                )
                return outputURL
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                throw error
            }
        }.value
    }

    // MARK: - Private

    private static func renderVideo(
        videoURL: URL,
        timeRange: CMTimeRange,
        outputURL: URL,
        options: VideoExportOptions
    ) async throws {
        let exportStartedAt = Date()
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

        // ScreenCaptureKit recordings are variable-frame-rate (frames only when
        // the screen changes), so a failed estimate means "trust the requested
        // fps" — the video composition fills the gaps at a constant rate.
        let requestedFps = max(1, options.fps)
        let effectiveFps: Int
        if let sourceFps = await estimateSourceFrameRate(asset: asset, track: sourceVideoTrack, timeRange: clampedRange) {
            effectiveFps = Int(min(Double(requestedFps), sourceFps.rounded(.down)))
        } else {
            effectiveFps = requestedFps
        }

        let (renderSize, transform) = try await computeRenderSizeAndTransform(
            track: sourceVideoTrack,
            maxSize: options.resolution.maxSize
        )

        let composition = AVMutableComposition()
        guard
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw VideoExportError.exportFailed(underlying: nil)
        }

        try compositionVideoTrack.insertTimeRange(clampedRange, of: sourceVideoTrack, at: .zero)

        // Clips recorded with system audio carry an audio track; trim it with
        // the same range so it stays in sync with the exported video.
        var compositionAudioTrack: AVMutableCompositionTrack?
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        if let sourceAudioTrack = audioTracks.first,
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        {
            do {
                try audioTrack.insertTimeRange(clampedRange, of: sourceAudioTrack, at: .zero)
                compositionAudioTrack = audioTrack
            } catch {
                AppLogger.capture.warning("Audio track could not be trimmed, exporting without audio: \(error.localizedDescription)")
            }
        }

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
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
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

        // Audio: decode to a normalized PCM layout and re-encode as AAC so the
        // writer settings always match, whatever SCK recorded. Both ends are
        // added together or not at all (an unread reader output can stall).
        var audioReaderOutput: AVAssetReaderAudioMixOutput?
        var audioWriterInput: AVAssetWriterInput?
        if let compositionAudioTrack {
            let readerAudioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
            ]
            let output = AVAssetReaderAudioMixOutput(audioTracks: [compositionAudioTrack], audioSettings: readerAudioSettings)
            output.alwaysCopiesSampleData = false

            let writerAudioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000,
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: writerAudioSettings)
            input.expectsMediaDataInRealTime = false

            if reader.canAdd(output), writer.canAdd(input) {
                reader.add(output)
                writer.add(input)
                audioReaderOutput = output
                audioWriterInput = input
            } else {
                AppLogger.capture.warning("Audio pipeline rejected by reader/writer, exporting without audio")
            }
        }

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
        let audioWriterInputBox = UncheckedSendableBox(value: audioWriterInput)
        let audioReaderOutputBox = UncheckedSendableBox(value: audioReaderOutput)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let hasAudio = audioWriterInputBox.value != nil && audioReaderOutputBox.value != nil
            let coordinator = ExportPumpCoordinator(
                reader: readerBox.value,
                writer: writerBox.value,
                pendingInputs: hasAudio ? 2 : 1,
                effectiveFps: effectiveFps,
                renderSize: renderSize,
                exportStartedAt: exportStartedAt,
                outputURL: outputURL,
                continuation: continuation
            )

            let targetFrameDuration = CMTime(value: 1, timescale: Int32(max(1, effectiveFps)))
            var nextAllowed = CMTime.zero
            var frameIndex: Int64 = 0
            var skippedFrames: Int64 = 0

            writerInputBox.value.requestMediaDataWhenReady(on: coordinator.queue) {
                let writerInput = writerInputBox.value
                let readerOutput = readerOutputBox.value

                if coordinator.isFinished {
                    writerInput.markAsFinished()
                    return
                }

                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        if pts < nextAllowed {
                            skippedFrames += 1
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
                            coordinator.abort(VideoExportError.exportFailed(underlying: nil))
                            return
                        }

                        if !writerInput.append(outputBuffer) {
                            writerInput.markAsFinished()
                            coordinator.abort(VideoExportError.exportFailed(underlying: writerBox.value.error))
                            return
                        }

                        frameIndex += 1
                        nextAllowed = pts + targetFrameDuration
                    } else {
                        writerInput.markAsFinished()
                        coordinator.finishVideoInput(appendedFrames: frameIndex, skippedFrames: skippedFrames)
                        return
                    }
                }
            }

            if hasAudio {
                let audioInputBox = UncheckedSendableBox(value: audioWriterInputBox.value!)
                let audioOutputBox = UncheckedSendableBox(value: audioReaderOutputBox.value!)

                audioInputBox.value.requestMediaDataWhenReady(on: coordinator.queue) {
                    let audioInput = audioInputBox.value
                    let audioOutput = audioOutputBox.value

                    if coordinator.isFinished {
                        audioInput.markAsFinished()
                        return
                    }

                    while audioInput.isReadyForMoreMediaData {
                        if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                            if !audioInput.append(sampleBuffer) {
                                audioInput.markAsFinished()
                                coordinator.abort(VideoExportError.exportFailed(underlying: writerBox.value.error))
                                return
                            }
                        } else {
                            audioInput.markAsFinished()
                            coordinator.inputFinished()
                            return
                        }
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
        let timestamp = AppDateFormatters.highPrecisionFilenameTimestamp()
        return "PeekOCR_\(timestamp)"
    }

    private func generateUniqueOutputURL(in outputDirectory: URL) -> URL {
        let baseName = generateFilename()
        var candidateURL =
            outputDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("mp4")
        var counter = 1

        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL =
                outputDirectory
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

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
