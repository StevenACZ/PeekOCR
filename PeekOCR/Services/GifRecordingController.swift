//
//  GifRecordingController.swift
//  PeekOCR
//
//  Orchestrates region selection, countdown, and video recording for GIF capture.
//

import AppKit
import CoreGraphics
import Darwin
import os

/// Controller that records a short region video and returns a temporary `.mov` URL.
@MainActor
final class GifRecordingController {
    static let shared = GifRecordingController()

    private let recordingService = NativeScreenRecordingService.shared

    private enum Phase {
        case idle
        case selecting
        case recording
    }

    private var overlayController: GifRecordingOverlayWindowController?
    private var recordingProcess: Process?
    private var countdownTask: Task<Void, Never>?
    private var outputURL: URL?
    private var phase: Phase = .idle
    private var cancelRequested = false

    private init() {}

    var isRecording: Bool {
        recordingProcess?.isRunning == true
    }

    func record(maxDurationSeconds: Int) async -> URL? {
        guard !isRecording else { return outputURL }

        cancelRequested = false
        phase = .selecting
        let overlay = GifRecordingOverlayWindowController()
        overlayController = overlay

        guard let selection = await overlay.runSelection() else {
            overlayController = nil
            phase = .idle
            return nil
        }

        phase = .recording
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        outputURL = tempURL

        let captureRect = convertToCaptureRect(selectionRectInScreen: selection.rect, screen: selection.screen)
        guard captureRect.width >= 1, captureRect.height >= 1 else {
            overlay.closeOverlay()
            overlayController = nil
            outputURL = nil
            return nil
        }

        overlay.beginRecording(
            selectionRectInScreen: selection.rect,
            screen: selection.screen,
            onStop: { [weak self] in
                self?.stop()
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )
        startElapsedTimer(maxDurationSeconds: maxDurationSeconds)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-R\(Int(captureRect.origin.x)),\(Int(captureRect.origin.y)),\(Int(captureRect.width)),\(Int(captureRect.height))",
            "-v",
            "-x",
            tempURL.path,
        ]

        do {
            try process.run()
        } catch {
            AppLogger.capture.error("Failed to start region recording: \(error.localizedDescription)")
            cleanupAfterRecording()
            return nil
        }

        recordingProcess = process

        let terminationStatus: Int32 = await Task.detached(priority: .userInitiated) {
            process.waitUntilExit()
            return process.terminationStatus
        }.value

        let exists = await Self.waitForVideoFile(at: tempURL, timeoutSeconds: 3.0)
        AppLogger.capture.info("Region recording ended (status=\(terminationStatus)) fileExists=\(exists)")

        if cancelRequested {
            if exists {
                try? FileManager.default.removeItem(at: tempURL)
            }
            cleanupAfterRecording()
            return nil
        }

        cleanupAfterRecording()
        return exists ? tempURL : nil
    }

    func stop() {
        if phase == .selecting {
            overlayController?.cancelSelection()
            return
        }

        if let process = recordingProcess, process.isRunning {
            kill(process.processIdentifier, SIGINT)
        }
    }

    func cancel() {
        cancelRequested = true
        stop()
    }

    // MARK: - Private

    private func startElapsedTimer(maxDurationSeconds: Int) {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for elapsed in 0...maxDurationSeconds {
                self.overlayController?.updateElapsedSeconds(elapsed)
                if elapsed == maxDurationSeconds { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !self.isRecording { return }
            }
            if self.isRecording {
                self.stop()
            }
        }
    }

    private func cleanupAfterRecording() {
        countdownTask?.cancel()
        countdownTask = nil

        overlayController?.closeOverlay()
        overlayController = nil

        recordingProcess = nil
        outputURL = nil
        phase = .idle
    }

    private func convertToCaptureRect(selectionRectInScreen: CGRect, screen: NSScreen) -> CGRect {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return selectionRectInScreen
        }

        let displayBounds = CGDisplayBounds(displayID)

        // Convert from AppKit (origin bottom-left) to CoreGraphics (origin top-left, y-down) within the display.
        let localX = selectionRectInScreen.origin.x - screen.frame.origin.x
        let localY = selectionRectInScreen.origin.y - screen.frame.origin.y
        let yFromTop = screen.frame.height - localY - selectionRectInScreen.height

        return CGRect(
            x: displayBounds.origin.x + localX,
            y: displayBounds.origin.y + yFromTop,
            width: selectionRectInScreen.width,
            height: selectionRectInScreen.height
        )
    }

    private nonisolated static func waitForVideoFile(at url: URL, timeoutSeconds: TimeInterval) async -> Bool {
        let minimumSizeBytes: Int64 = 1_024
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        var lastSize: Int64?
        var stableReads = 0

        while Date() < deadline {
            guard let size = fileSizeBytes(at: url) else {
                stableReads = 0
                lastSize = nil
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            guard size >= minimumSizeBytes else {
                stableReads = 0
                lastSize = size
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            if size == lastSize {
                stableReads += 1
                if stableReads >= 2 {
                    return true
                }
            } else {
                stableReads = 0
                lastSize = size
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard let finalSize = fileSizeBytes(at: url) else { return false }
        return finalSize >= minimumSizeBytes
    }

    private nonisolated static func fileSizeBytes(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return size.int64Value
    }
}
