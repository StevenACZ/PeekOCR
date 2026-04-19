//
//  CaptureSoundService.swift
//  PeekOCR
//
//  Plays a bundled shutter sound asynchronously on capture completion.
//

import AVFoundation
import Foundation
import os

@MainActor
final class CaptureSoundService {
    static let shared = CaptureSoundService()

    private let settings = SoundSettings.shared
    private var player: AVAudioPlayer?
    private var didAttemptLoad = false

    private init() {}

    /// Fire-and-forget playback. Returns immediately; actual playback runs on the audio engine.
    func play() {
        guard settings.captureSoundEnabled else { return }
        ensurePlayerLoaded()
        guard let player else { return }
        player.volume = Float(settings.captureSoundVolume)
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    private func ensurePlayerLoaded() {
        guard !didAttemptLoad else { return }
        didAttemptLoad = true

        guard let url = Bundle.main.url(forResource: "capture-shutter", withExtension: "m4a") else {
            AppLogger.capture.error("CaptureSoundService: capture-shutter.m4a missing from bundle")
            return
        }

        do {
            let loaded = try AVAudioPlayer(contentsOf: url)
            loaded.prepareToPlay()
            self.player = loaded
        } catch {
            AppLogger.capture.error("CaptureSoundService: failed to load player — \(error.localizedDescription)")
        }
    }
}
