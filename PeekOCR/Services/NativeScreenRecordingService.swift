//
//  NativeScreenRecordingService.swift
//  PeekOCR
//
//  Records short screen videos using macOS native screencapture.
//

import Foundation
import os

/// Service that uses macOS native screencapture command to record short screen videos
final class NativeScreenRecordingService {
    static let shared = NativeScreenRecordingService()

    private init() {}

    // MARK: - Public Methods

    /// Returns true if the current OS supports `screencapture` video flags.
    func supportsInteractiveVideoCapture() async -> Bool {
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-h"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                return false
            }

            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.contains("-v")
        }.value
    }

    /// Record a user-selected screen region to a temporary `.mov` file.
    /// - Parameter maxDurationSeconds: Maximum duration for the recording.
    /// - Returns: URL of the recorded video, or nil if cancelled/failed.
    func recordInteractive(maxDurationSeconds: Int) async -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        AppLogger.capture.info("Starting interactive video recording (max \(maxDurationSeconds)s)")

        let success = await runScreenRecording(
            outputPath: tempURL.path,
            maxDurationSeconds: maxDurationSeconds
        )

        guard success else {
            try? FileManager.default.removeItem(at: tempURL)
            AppLogger.capture.info("Video recording cancelled or failed")
            return nil
        }

        AppLogger.capture.info("Video recording completed: \(tempURL.lastPathComponent)")
        return tempURL
    }

    // MARK: - Private Methods

    private func runScreenRecording(outputPath: String, maxDurationSeconds: Int) async -> Bool {
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = [
                "-i",
                "-s",
                "-Jvideo",
                "-v",
                "-V\(maxDurationSeconds)",
                "-x",
                outputPath,
            ]

            do {
                try process.run()
            } catch {
                return false
            }

            process.waitUntilExit()

            let fileExists = Self.waitForFile(atPath: outputPath, timeoutSeconds: 1.0)
            return process.terminationStatus == 0 && fileExists
        }.value
    }

    private nonisolated static func waitForFile(atPath path: String, timeoutSeconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return FileManager.default.fileExists(atPath: path)
    }
}
