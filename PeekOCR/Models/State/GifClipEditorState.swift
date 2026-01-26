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

    let videoURL: URL
    let maxDurationSeconds: Int
    let player: AVPlayer

    @Published private(set) var isReady = false
    @Published private(set) var loadErrorMessage: String?

    @Published private(set) var durationSeconds: Double = 0
    @Published var startSeconds: Double = 0
    @Published var endSeconds: Double = 0

    @Published var isPreviewPlaying = false

    // MARK: - Private Properties

    private let asset: AVURLAsset
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
            let duration = try await asset.load(.duration)
            let rawSeconds = duration.seconds.isFinite ? duration.seconds : 0
            let clampedSeconds = min(rawSeconds, Double(maxDurationSeconds))
            durationSeconds = max(0, clampedSeconds)
            startSeconds = 0
            endSeconds = durationSeconds
        } catch {
            AppLogger.capture.error("Failed to load video duration: \(error.localizedDescription)")
            loadErrorMessage = "No se pudo cargar el video. Intenta grabar de nuevo."
            durationSeconds = 0
            startSeconds = 0
            endSeconds = 0
        }

        isReady = true
    }

    func playSelection() {
        guard durationSeconds > 0 else { return }
        seek(toSeconds: startSeconds)
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
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func currentTimeRange() -> CMTimeRange {
        let start = CMTime(seconds: max(0, startSeconds), preferredTimescale: 600)
        let end = CMTime(seconds: max(startSeconds, endSeconds), preferredTimescale: 600)
        return CMTimeRangeFromTimeToTime(start: start, end: end)
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
        if player.currentTime().seconds >= endSeconds {
            stopPlayback()
        }
    }
}
