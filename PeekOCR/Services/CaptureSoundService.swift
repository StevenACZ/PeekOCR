//
//  CaptureSoundService.swift
//  PeekOCR
//
//  Plays capture/OCR feedback sounds asynchronously with zero-latency preloading.
//

import AVFoundation
import AppKit
import Foundation
import os

@MainActor
final class CaptureSoundService {
    static let shared = CaptureSoundService()

    private let settings = SoundSettings.shared
    private var shutterPlayer: AVAudioPlayer?
    private var didAttemptShutterLoad = false

    private init() {}

    /// Loads audio resources ahead of time so the first capture plays instantly.
    func prewarm() {
        ensureShutterLoaded()
    }

    /// Fire-and-forget playback for a completed capture (screenshot, GIF, video).
    func playCapture() {
        guard settings.captureSoundEnabled else { return }
        play(settings.captureSound, volume: Float(settings.captureSoundVolume))
    }

    /// Subtle confirmation when OCR text or a QR payload lands on the clipboard.
    func playOCRFeedback() {
        guard settings.captureSoundEnabled, settings.ocrFeedbackEnabled else { return }
        playSystemSound("Tink", volume: Float(settings.captureSoundVolume) * 0.8)
    }

    /// Plays a sound once so the user can audition it from Settings.
    func preview(_ sound: CaptureSound) {
        play(sound, volume: Float(settings.captureSoundVolume))
    }

    // MARK: - Private

    private func play(_ sound: CaptureSound, volume: Float) {
        if let systemSoundName = sound.systemSoundName {
            playSystemSound(systemSoundName, volume: volume)
            return
        }

        ensureShutterLoaded()
        guard let shutterPlayer else { return }
        shutterPlayer.volume = volume
        if shutterPlayer.isPlaying {
            shutterPlayer.currentTime = 0
        }
        shutterPlayer.play()
    }

    private func playSystemSound(_ name: String, volume: Float) {
        guard let sound = NSSound(named: name) else {
            AppLogger.capture.error("CaptureSoundService: system sound \(name) not found")
            return
        }
        sound.volume = volume
        sound.stop()
        sound.play()
    }

    private func ensureShutterLoaded() {
        guard !didAttemptShutterLoad else { return }
        didAttemptShutterLoad = true

        guard let url = Bundle.main.url(forResource: "capture-shutter", withExtension: "m4a") else {
            AppLogger.capture.error("CaptureSoundService: capture-shutter.m4a missing from bundle")
            return
        }

        do {
            let loaded = try AVAudioPlayer(contentsOf: url)
            loaded.prepareToPlay()
            self.shutterPlayer = loaded
        } catch {
            AppLogger.capture.error("CaptureSoundService: failed to load player — \(error.localizedDescription)")
        }
    }
}
