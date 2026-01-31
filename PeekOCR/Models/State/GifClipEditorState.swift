//
//  GifClipEditorState.swift
//  PeekOCR
//
//  State and playback control for trimming a recorded video into a GIF clip.
//

import AVFoundation
import AVKit
import Combine
import os

/// State model for GIF clip trimming UI
@MainActor
final class GifClipEditorState: NSObject, ObservableObject {
    // MARK: - Public Properties

    let maxDurationSeconds: Int
    let player: AVPlayer

    @Published private(set) var videoURL: URL
    @Published private(set) var isReady = false
    @Published private(set) var loadErrorMessage: String?

    @Published private(set) var durationSeconds: Double = 0
    @Published var startSeconds: Double = 0
    @Published var endSeconds: Double = 0

    @Published private(set) var currentSeconds: Double = 0
    @Published var isPreviewPlaying = false
    @Published private(set) var sourceNominalFps: Double = 30

    // MARK: - Private Properties

    private var asset: AVURLAsset
    private var playbackTimer: Timer?

    // MARK: - Initialization

    init(videoURL: URL, maxDurationSeconds: Int) {
        self.videoURL = videoURL
        self.maxDurationSeconds = maxDurationSeconds
        self.asset = AVURLAsset(url: videoURL)
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        super.init()
    }

    deinit {
        playbackTimer?.invalidate()
    }

    // MARK: - Public Methods

    func prepare() async {
        isReady = false
        loadErrorMessage = nil

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                do {
                    let nominalFrameRate = try await track.load(.nominalFrameRate)
                    if nominalFrameRate.isFinite, nominalFrameRate > 0 {
                        sourceNominalFps = Double(nominalFrameRate)
                    } else {
                        sourceNominalFps = 30
                    }
                } catch {
                    sourceNominalFps = 30
                }
            } else {
                sourceNominalFps = 30
            }

            let duration = try await asset.load(.duration)
            let rawSeconds = duration.seconds.isFinite ? duration.seconds : 0
            let clampedSeconds = min(rawSeconds, Double(maxDurationSeconds))
            durationSeconds = max(0, clampedSeconds)
            startSeconds = 0
            endSeconds = durationSeconds
            currentSeconds = 0

            if sourceNominalFps < 55, let estimated = await Self.estimateSourceFrameRate(videoURL: videoURL) {
                sourceNominalFps = estimated
            }
        } catch {
            AppLogger.capture.error("Failed to load video duration: \(error.localizedDescription)")
            loadErrorMessage = "No se pudo cargar el video. Intenta grabar de nuevo."
            durationSeconds = 0
            startSeconds = 0
            endSeconds = 0
            currentSeconds = 0
        }

        isReady = true
    }

    func setVideo(url: URL) async {
        stopPlayback()
        isReady = false
        loadErrorMessage = nil

        videoURL = url
        asset = AVURLAsset(url: url)
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        await prepare()
    }

    func playSelection() {
        guard durationSeconds > 0 else { return }
        if currentSeconds < startSeconds || currentSeconds > endSeconds {
            seek(toSeconds: startSeconds)
        }
        isPreviewPlaying = true
        startPlaybackMonitor()
        player.play()
    }

    func stopPlayback() {
        isPreviewPlaying = false
        stopPlaybackMonitor()
        player.pause()
    }

    func seek(toSeconds seconds: Double) {
        let clamped = max(0, min(seconds, durationSeconds))
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentSeconds = clamped
    }

    func currentTimeRange() -> CMTimeRange {
        let start = CMTime(seconds: max(0, startSeconds), preferredTimescale: 600)
        let end = CMTime(seconds: max(startSeconds, endSeconds), preferredTimescale: 600)
        return CMTimeRangeFromTimeToTime(start: start, end: end)
    }

    func stepFrame(delta: Int) {
        guard durationSeconds > 0 else { return }
        let stepSeconds = 1.0 / max(1, sourceNominalFps)
        let target = currentSeconds + (Double(delta) * stepSeconds)
        let clamped = max(0, min(target, durationSeconds))

        if clamped < startSeconds {
            startSeconds = clamped
        }
        if clamped > endSeconds {
            endSeconds = clamped
        }

        seek(toSeconds: clamped)
    }

    // MARK: - Private Methods

    private func startPlaybackMonitor() {
        stopPlaybackMonitor()

        playbackTimer = Timer.scheduledTimer(
            timeInterval: 0.05,
            target: self,
            selector: #selector(handlePlaybackTimer),
            userInfo: nil,
            repeats: true
        )

        RunLoop.main.add(playbackTimer!, forMode: .common)
    }

    private func stopPlaybackMonitor() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    @objc
    private func handlePlaybackTimer(_ timer: Timer) {
        guard isPreviewPlaying else { return }
        let current = player.currentTime().seconds
        if current.isFinite {
            currentSeconds = current
        }

        if current >= endSeconds {
            stopPlayback()
        }
    }

    private nonisolated static func estimateSourceFrameRate(videoURL: URL) async -> Double? {
        return await Task.detached(priority: .utility) {
            do {
                let asset = AVURLAsset(url: videoURL)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else { return nil }

                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: 2.0, preferredTimescale: 600)
                )

                let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                output.alwaysCopiesSampleData = false

                guard reader.canAdd(output) else { return nil }
                reader.add(output)

                guard reader.startReading() else { return nil }

                var lastTimestamp: Double?
                var deltas: [Double] = []

                while deltas.count < 60, let sample = output.copyNextSampleBuffer() {
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
        }.value
    }

    private nonisolated static func normalizeEstimatedFps(_ fps: Double) -> Double? {
        guard fps.isFinite, fps >= 10, fps <= 120 else { return nil }

        let candidates: [Double] = [60.0, 59.94, 30.0, 29.97, 24.0]
        guard let best = candidates.min(by: { abs($0 - fps) < abs($1 - fps) }) else { return nil }

        if abs(best - fps) <= 2.0 {
            return best.rounded()
        }
        return nil
    }
}
