//
//  ClipRecordingController.swift
//  PeekOCR
//
//  Orchestrates clip capture: quick-select region pick (same overlay as the
//  screenshot hotkey), recording frame + HUD, and the ScreenCaptureKit engine.
//

import AppKit
import ScreenCaptureKit
import os

/// Controller that records a short region clip and returns a temporary `.mov` URL.
@MainActor
final class ClipRecordingController {
    static let shared = ClipRecordingController()

    private enum Phase {
        case idle
        case selecting
        case recording
        case paused
    }

    private var phase: Phase = .idle
    private var selectionOverlay: LiveAnnotationOverlayWindowController?
    private var engine: ScreenRecordingEngine?
    private var frameController: RecordingFrameWindowController?
    private var hudController: RecordingHudWindowController?
    private var countdownTask: Task<Void, Never>?
    /// In-flight pause/resume; new toggles are ignored and stop waits for it.
    private var pauseTransitionTask: Task<Void, Never>?
    private var elapsedSeconds = 0
    /// Resumed with `true` when the recording should be discarded.
    private var stopRequest: CheckedContinuation<Bool, Never>?

    private init() {}

    var isRecording: Bool {
        phase == .recording || phase == .paused
    }

    /// Record a region clip. Returns the temporary `.mov` URL, or nil if cancelled/failed.
    /// - Parameter maxDurationSeconds: nil records until the user stops.
    func record(maxDurationSeconds: Int?) async -> URL? {
        guard phase == .idle else { return nil }

        phase = .selecting
        let overlay = LiveAnnotationOverlayWindowController()
        selectionOverlay = overlay

        guard let session = await overlay.runSession(mode: .quickSelect) else {
            selectionOverlay = nil
            phase = .idle
            AppLogger.capture.info("Clip region selection cancelled")
            return nil
        }
        selectionOverlay = nil
        phase = .recording
        elapsedSeconds = 0

        let settings = GifClipSettings.shared
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        let configuration = ScreenRecordingConfiguration(
            rectInScreen: session.selectionRect,
            screen: session.screen,
            fps: settings.recordingFps,
            showsCursor: settings.recordingShowsCursor,
            capturesSystemAudio: settings.recordingCapturesSystemAudio,
            outputURL: outputURL
        )

        // Frame + HUD go up BEFORE the engine starts: besides instant feedback,
        // the engine's shareable-content snapshot only lists apps with
        // on-screen windows, and this app must be in it to be excluded from
        // the recorded pixels.
        let frame = RecordingFrameWindowController()
        frame.show(around: session.selectionRect)
        frameController = frame

        let hud = RecordingHudWindowController()
        hud.show(
            on: session.screen,
            selectionRectInScreen: session.selectionRect,
            maxDurationSeconds: maxDurationSeconds ?? 0,
            quality: Self.qualityText(configuration: configuration),
            onStop: { [weak self] in
                self?.stop()
            },
            onTogglePause: { [weak self] in
                self?.togglePause()
            }
        )
        hudController = hud

        let engine = ScreenRecordingEngine()
        engine.onRuntimeStop = { [weak self] in
            self?.stop()
        }
        self.engine = engine

        do {
            try await engine.start(configuration: configuration)
        } catch {
            AppLogger.capture.error("Failed to start clip recording: \(error.localizedDescription)")
            cleanup()
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }

        startCountdown(maxDurationSeconds: maxDurationSeconds)

        let cancelRequested = await withCheckedContinuation { continuation in
            stopRequest = continuation
        }

        // Let an in-flight pause/resume settle before tearing the stream down,
        // so the engine never waits on two finish continuations at once.
        if let transition = pauseTransitionTask {
            await transition.value
        }

        let finishedOK = await engine.stop()
        cleanup()

        guard finishedOK, !cancelRequested else {
            try? FileManager.default.removeItem(at: outputURL)
            if cancelRequested {
                AppLogger.capture.info("Clip recording cancelled, file discarded")
            } else {
                AppLogger.capture.error("Clip recording did not produce a valid file")
            }
            return nil
        }

        AppLogger.capture.info("Clip recorded: \(outputURL.lastPathComponent)")
        return outputURL
    }

    /// Stop the current phase: cancels region selection, or finishes the
    /// recording and keeps the file.
    func stop() {
        switch phase {
        case .selecting:
            selectionOverlay?.cancelSession()
        case .recording, .paused:
            resolveStopRequest(cancelRequested: false)
        case .idle:
            break
        }
    }

    /// Abort and discard: cancels selection, or stops recording and deletes the file.
    func cancel() {
        switch phase {
        case .selecting:
            selectionOverlay?.cancelSession()
        case .recording, .paused:
            resolveStopRequest(cancelRequested: true)
        case .idle:
            break
        }
    }

    /// Pause or resume the active recording (HUD pause button).
    func togglePause() {
        guard pauseTransitionTask == nil else { return }

        switch phase {
        case .recording:
            phase = .paused
            hudController?.setPaused(true)
            frameController?.setPaused(true)
            pauseTransitionTask = Task { @MainActor [weak self] in
                await self?.engine?.pause()
                self?.pauseTransitionTask = nil
            }
        case .paused:
            pauseTransitionTask = Task { @MainActor [weak self] in
                defer { self?.pauseTransitionTask = nil }
                guard let self, let engine = self.engine, self.phase == .paused else { return }
                do {
                    try await engine.resume()
                    self.phase = .recording
                    self.hudController?.setPaused(false)
                    self.frameController?.setPaused(false)
                } catch {
                    AppLogger.capture.error("Failed to resume recording: \(error.localizedDescription)")
                    self.stop()
                }
            }
        case .idle, .selecting:
            break
        }
    }

    // MARK: - Private

    private func resolveStopRequest(cancelRequested: Bool) {
        stopRequest?.resume(returning: cancelRequested)
        stopRequest = nil
    }

    private func startCountdown(maxDurationSeconds: Int?) {
        countdownTask?.cancel()
        let hudMax = maxDurationSeconds ?? 0
        hudController?.update(elapsedSeconds: 0, maxDurationSeconds: hudMax)

        countdownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }

                switch self.phase {
                case .paused:
                    continue  // frozen clock while paused
                case .recording:
                    break
                case .idle, .selecting:
                    return
                }

                self.elapsedSeconds += 1
                self.hudController?.update(elapsedSeconds: self.elapsedSeconds, maxDurationSeconds: hudMax)

                if let limit = maxDurationSeconds, self.elapsedSeconds >= limit {
                    self.stop()
                    return
                }
            }
        }
    }

    private func cleanup() {
        countdownTask?.cancel()
        countdownTask = nil
        pauseTransitionTask = nil
        hudController?.closeHud()
        hudController = nil
        frameController?.hide()
        frameController = nil
        engine = nil
        stopRequest = nil
        elapsedSeconds = 0
        phase = .idle
    }

    /// "1080p · 30 FPS · GIF · Audio" readout for the HUD.
    private static func qualityText(configuration: ScreenRecordingConfiguration) -> String {
        let pixelHeight = Int(configuration.rectInScreen.height * configuration.screen.backingScaleFactor)
        var parts = [
            resolutionLabel(pixelHeight: pixelHeight),
            "\(configuration.fps) FPS",
            GifClipSettings.shared.defaultExportFormat.displayName,
        ]
        if configuration.capturesSystemAudio {
            parts.append("Audio")
        }
        return parts.joined(separator: " · ")
    }

    private static func resolutionLabel(pixelHeight: Int) -> String {
        switch pixelHeight {
        case 2160...: return "4K"
        case 1440..<2160: return "2K"
        case 1080..<1440: return "1080p"
        case 720..<1080: return "720p"
        default: return "\(pixelHeight)p"
        }
    }
}
