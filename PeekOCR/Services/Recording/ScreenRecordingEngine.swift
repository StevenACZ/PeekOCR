//
//  ScreenRecordingEngine.swift
//  PeekOCR
//
//  Records a screen region straight to a movie file using ScreenCaptureKit's
//  SCRecordingOutput (macOS 15+): no helper process, instant start/stop, and
//  this app's own windows (recording frame, HUD) are excluded from the pixels.
//
//  Pause/resume works by swapping recording outputs on the live stream: each
//  resume writes a new segment file, and stop() concatenates the segments
//  into the final movie with a passthrough export (no re-encode).
//

import AVFoundation
import AppKit
import ScreenCaptureKit
import os

/// Configuration for a single region recording session.
struct ScreenRecordingConfiguration {
    let rectInScreen: CGRect
    let screen: NSScreen
    let fps: Int
    let showsCursor: Bool
    let capturesSystemAudio: Bool
    let outputURL: URL
}

/// One-shot ScreenCaptureKit recording engine. Create one instance per recording.
@MainActor
final class ScreenRecordingEngine: NSObject {
    enum EngineError: LocalizedError {
        case displayNotFound
        case regionTooSmall
        case concatenationFailed

        var errorDescription: String? {
            switch self {
            case .displayNotFound: return "No se encontró la pantalla a grabar."
            case .regionTooSmall: return "La región seleccionada es demasiado pequeña."
            case .concatenationFailed: return "No se pudieron unir los segmentos grabados."
            }
        }
    }

    /// Called when the stream stops on its own (system error, permission revoked).
    var onRuntimeStop: (() -> Void)?

    private var stream: SCStream?
    private var currentOutput: SCRecordingOutput?
    private var finalOutputURL: URL?
    private var segmentURLs: [URL] = []
    private var recordingConfigurationTemplate: (fileType: AVFileType, codec: AVVideoCodecType) = (.mov, .h264)

    private var currentSegmentFinished = false
    private var currentSegmentError: Error?
    private var finishContinuation: CheckedContinuation<Void, Never>?

    /// Build the filter + stream and start capturing into the first segment.
    /// IMPORTANT: call this AFTER the recording frame/HUD windows are on
    /// screen. The shareable-content snapshot only lists apps that own
    /// on-screen windows, and this menu-bar app must be in that list for the
    /// exclusion filter to keep its windows out of the recording.
    func start(configuration: ScreenRecordingConfiguration) async throws {
        // System audio needs its own TCC grant on macOS 26; if the stream
        // refuses to start with audio, fall back to a video-only recording.
        if configuration.capturesSystemAudio {
            do {
                try await startStream(configuration: configuration, capturesAudio: true)
                return
            } catch {
                AppLogger.capture.warning(
                    "System audio capture unavailable, retrying without audio: \(error.localizedDescription)")
                cleanupSegmentFiles()
            }
        }
        try await startStream(configuration: configuration, capturesAudio: false)
    }

    /// Finalize the current segment but keep the stream alive.
    func pause() async {
        guard let stream, let output = currentOutput else { return }
        currentOutput = nil

        do {
            try stream.removeRecordingOutput(output)
        } catch {
            AppLogger.capture.error("Failed to remove recording output on pause: \(error.localizedDescription)")
        }
        if !currentSegmentFinished {
            await waitForFinish(timeoutSeconds: 3)
        }
        AppLogger.capture.info("SCK recording paused after segment \(self.segmentURLs.count)")
    }

    /// Start writing a new segment on the live stream.
    func resume() async throws {
        guard let stream, currentOutput == nil, let finalOutputURL else { return }

        let segmentURL = Self.segmentURL(for: finalOutputURL, index: segmentURLs.count)
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = segmentURL
        recordingConfiguration.outputFileType = recordingConfigurationTemplate.fileType
        recordingConfiguration.videoCodecType = recordingConfigurationTemplate.codec

        currentSegmentFinished = false
        currentSegmentError = nil

        let output = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
        try stream.addRecordingOutput(output)
        currentOutput = output
        segmentURLs.append(segmentURL)
        AppLogger.capture.info("SCK recording resumed with segment \(self.segmentURLs.count)")
    }

    /// Stop capturing, wait for the active segment to finalize, and produce
    /// the final movie (moving or concatenating segments as needed).
    /// - Returns: true when the final file is ready at the configured URL.
    func stop() async -> Bool {
        guard let stream, let finalOutputURL else { return false }

        let hadActiveOutput = currentOutput != nil
        do {
            try await stream.stopCapture()
        } catch {
            AppLogger.capture.debug("stopCapture after stream already stopped: \(error.localizedDescription)")
        }
        if hadActiveOutput, !currentSegmentFinished {
            await waitForFinish(timeoutSeconds: 3)
        }

        self.stream = nil
        self.currentOutput = nil

        let validSegments = segmentURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !validSegments.isEmpty else {
            AppLogger.capture.error("SCK recording produced no playable segments")
            return false
        }

        do {
            try? FileManager.default.removeItem(at: finalOutputURL)
            if validSegments.count == 1 {
                try FileManager.default.moveItem(at: validSegments[0], to: finalOutputURL)
            } else {
                try await Self.concatenateSegments(validSegments, to: finalOutputURL)
                cleanupSegmentFiles()
            }
            AppLogger.capture.info("SCK recording finalized (\(validSegments.count) segment(s))")
            return true
        } catch {
            AppLogger.capture.error("Failed to finalize recording: \(error.localizedDescription)")
            cleanupSegmentFiles()
            return false
        }
    }

    // MARK: - Stream setup

    private func startStream(configuration: ScreenRecordingConfiguration, capturesAudio: Bool) async throws {
        currentSegmentFinished = false
        currentSegmentError = nil
        segmentURLs = []
        finalOutputURL = configuration.outputURL

        let screen = configuration.screen
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else {
            throw EngineError.displayNotFound
        }

        // Fetched here — after the caller put the frame/HUD on screen — so
        // this app shows up in the snapshot and can be excluded.
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw EngineError.displayNotFound
        }

        // Excluding by application (not by window list) keeps windows the app
        // creates later — flash, popover — out of the recording too. Fall back
        // to the window list if the snapshot somehow misses the app.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownApplications = shareableContent.applications.filter { $0.processID == ownPID }
        let filter: SCContentFilter
        if !ownApplications.isEmpty {
            filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        } else {
            let ownWindows = shareableContent.windows.filter { $0.owningApplication?.processID == ownPID }
            AppLogger.capture.warning(
                "Own app missing from shareable content applications; excluding \(ownWindows.count) windows instead")
            filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        }

        let rect = configuration.rectInScreen
        let scale = screen.backingScaleFactor
        let pixelWidth = Self.evenPixelLength(rect.width * scale)
        let pixelHeight = Self.evenPixelLength(rect.height * scale)
        guard pixelWidth >= 2, pixelHeight >= 2 else { throw EngineError.regionTooSmall }

        // sourceRect is display-local with a top-left origin, in points.
        let localX = rect.origin.x - screen.frame.origin.x
        let localYFromTop = screen.frame.height - (rect.origin.y - screen.frame.origin.y) - rect.height

        let fps = max(1, configuration.fps)
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.sourceRect = CGRect(x: localX, y: localYFromTop, width: rect.width, height: rect.height)
        streamConfiguration.width = pixelWidth
        streamConfiguration.height = pixelHeight
        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        streamConfiguration.showsCursor = configuration.showsCursor
        streamConfiguration.capturesAudio = capturesAudio
        if capturesAudio {
            streamConfiguration.excludesCurrentProcessAudio = true
        }
        streamConfiguration.captureResolution = .best

        // H.264 intermediate: fast universal decode for the clip editor.
        let segmentURL = Self.segmentURL(for: configuration.outputURL, index: 0)
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = segmentURL
        recordingConfiguration.outputFileType = recordingConfigurationTemplate.fileType
        recordingConfiguration.videoCodecType = recordingConfigurationTemplate.codec

        let output = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
        let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        try stream.addRecordingOutput(output)
        try await stream.startCapture()

        self.stream = stream
        self.currentOutput = output
        self.segmentURLs = [segmentURL]

        AppLogger.capture.info(
            "SCK recording started - \(pixelWidth)x\(pixelHeight)px @\(fps)fps cursor=\(configuration.showsCursor) audio=\(capturesAudio)")
    }

    // MARK: - Segment plumbing

    private static func segmentURL(for outputURL: URL, index: Int) -> URL {
        outputURL.deletingPathExtension()
            .appendingPathExtension("seg\(index)")
            .appendingPathExtension("mov")
    }

    private func cleanupSegmentFiles() {
        for url in segmentURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Joins same-encoder segments without re-encoding (passthrough export).
    private static func concatenateSegments(_ urls: [URL], to outputURL: URL) async throws {
        let composition = AVMutableComposition()
        var videoTrack: AVMutableCompositionTrack?
        var audioTrack: AVMutableCompositionTrack?
        var cursor = CMTime.zero

        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard duration.seconds > 0 else { continue }
            let range = CMTimeRange(start: .zero, duration: duration)

            if let sourceVideo = try await asset.loadTracks(withMediaType: .video).first {
                if videoTrack == nil {
                    videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                try videoTrack?.insertTimeRange(range, of: sourceVideo, at: cursor)
            }
            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                if audioTrack == nil {
                    audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                try audioTrack?.insertTimeRange(range, of: sourceAudio, at: cursor)
            }
            cursor = cursor + duration
        }

        guard videoTrack != nil,
            let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        else {
            throw EngineError.concatenationFailed
        }
        try await session.export(to: outputURL, as: .mov)
    }

    // MARK: - Finish waiting

    private func waitForFinish(timeoutSeconds: Double) async {
        guard !currentSegmentFinished else { return }

        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            self?.resumeFinishWaiter()
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finishContinuation = continuation
        }
        timeoutTask.cancel()
    }

    private func resumeFinishWaiter() {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    private func handleRecordingFinished(error: Error?) {
        currentSegmentFinished = true
        if let error {
            currentSegmentError = error
            AppLogger.capture.error("SCK recording output failed: \(error.localizedDescription)")
        } else {
            AppLogger.capture.debug("SCK recording output finished writing")
        }

        if finishContinuation != nil {
            resumeFinishWaiter()
        } else if error != nil {
            // Spontaneous failure mid-recording: let the controller stop and
            // salvage whatever segments are already on disk.
            onRuntimeStop?()
        }
    }

    private func handleStreamStopped(error: Error) {
        AppLogger.capture.error("SCK stream stopped on its own: \(error.localizedDescription)")
        onRuntimeStop?()
    }

    private static func evenPixelLength(_ points: CGFloat) -> Int {
        let pixels = Int(points.rounded(.down))
        return max(0, pixels - (pixels % 2))
    }
}

// MARK: - SCRecordingOutputDelegate

extension ScreenRecordingEngine: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            AppLogger.capture.debug("SCK recording output started writing")
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            self.handleRecordingFinished(error: nil)
        }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in
            self.handleRecordingFinished(error: error)
        }
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecordingEngine: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.handleStreamStopped(error: error)
        }
    }
}
