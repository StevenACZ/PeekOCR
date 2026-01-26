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

    // MARK: - Private Properties

    private var asset: AVURLAsset
    private var playbackTimer: Timer?
    private var videoFrameRate: Double = 30

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
            if let track = tracks.first, track.nominalFrameRate.isFinite, track.nominalFrameRate > 0 {
                videoFrameRate = Double(track.nominalFrameRate)
            } else {
                videoFrameRate = 30
            }

            let duration = try await asset.load(.duration)
            let rawSeconds = duration.seconds.isFinite ? duration.seconds : 0
            let clampedSeconds = min(rawSeconds, Double(maxDurationSeconds))
            durationSeconds = max(0, clampedSeconds)
            startSeconds = 0
            endSeconds = durationSeconds
            currentSeconds = 0
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
        let stepSeconds = 1.0 / max(1, videoFrameRate)
        let target = currentSeconds + (Double(delta) * stepSeconds)
        seek(toSeconds: target)
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
}
