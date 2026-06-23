//
//  NativeScreenCaptureService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import Foundation
import ImageIO
import ScreenCaptureKit
import os

/// Service that uses macOS native screencapture command for high-quality, reliable captures
final class NativeScreenCaptureService {
    static let shared = NativeScreenCaptureService()

    struct ScreenSnapshot {
        let displayID: CGDirectDisplayID
        let screen: NSScreen
        let image: CGImage

        func crop(rectInScreen: CGRect) -> CGImage? {
            let rect = rectInScreen.integral
            guard rect.width > 0, rect.height > 0 else { return nil }

            let scale = screen.backingScaleFactor
            let localX = (rect.minX - screen.frame.minX) * scale
            let localYFromTop = (screen.frame.height - (rect.minY - screen.frame.minY) - rect.height) * scale
            let cropRect = CGRect(
                x: localX,
                y: localYFromTop,
                width: rect.width * scale,
                height: rect.height * scale
            ).integral
            let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))
            let boundedRect = cropRect.intersection(imageBounds)
            guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else { return nil }

            return image.cropping(to: boundedRect)
        }
    }

    private init() {}

    // MARK: - Public Methods

    /// Capture a screen region and return the image data directly
    /// - Returns: PNG data of the captured image, or nil if cancelled
    func captureInteractiveAsData() async -> Data? {
        // Create a temporary file path
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        // Run screencapture command
        let success = await runScreenCapture(outputPath: tempURL.path)

        guard success else {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }

        // Read the file data into memory lazily to reduce peak allocations
        let data = try? Data(contentsOf: tempURL, options: .mappedIfSafe)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        return data
    }

    /// Capture to clipboard directly using native screencapture
    func captureToClipboard() async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive mode, -c: capture to clipboard
            process.arguments = ["-i", "-c"]

            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                AppLogger.capture.error("Failed to run screencapture: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    /// Capture a specific screen rect without showing the native picker.
    /// Uses ScreenCaptureKit (no helper process, no temp file) and excludes this
    /// app's own windows, so callers don't need to wait for overlays to vanish.
    /// - Parameters:
    ///   - rectInScreen: Rect in AppKit global screen coordinates.
    ///   - screen: The source screen containing the selection.
    /// - Returns: The captured image or nil on failure.
    func captureRegion(_ rectInScreen: CGRect, on screen: NSScreen) async -> CGImage? {
        let rect = rectInScreen.integral
        guard rect.width > 0, rect.height > 0 else { return nil }

        if let image = await captureRegionWithScreenCaptureKit(rect, on: screen) {
            return image
        }

        AppLogger.capture.warning("ScreenCaptureKit region capture failed, falling back to screencapture CLI")
        return await captureRegionWithCLI(rect, on: screen)
    }

    /// Capture each active screen before the app shows any selection overlay.
    /// Quick-select uses these frozen pixels so transient UI (menus, popovers,
    /// hovers) survives even if the source app dismisses it while selecting.
    func captureScreenSnapshots(
        for screens: [(displayID: CGDirectDisplayID, screen: NSScreen)]
    ) async -> [CGDirectDisplayID: ScreenSnapshot] {
        guard !screens.isEmpty else { return [:] }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }
            var snapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]

            for (displayID, screen) in screens {
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
                let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = CGRect(origin: .zero, size: screen.frame.size)
                configuration.width = max(1, Int((screen.frame.width * screen.backingScaleFactor).rounded()))
                configuration.height = max(1, Int((screen.frame.height * screen.backingScaleFactor).rounded()))
                configuration.showsCursor = false
                configuration.captureResolution = .best

                do {
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                    snapshots[displayID] = ScreenSnapshot(displayID: displayID, screen: screen, image: image)
                } catch {
                    AppLogger.capture.error(
                        "SCScreenshotManager screen snapshot failed for display \(displayID): \(error.localizedDescription)")
                }
            }

            return snapshots
        } catch {
            AppLogger.capture.error("Unable to enumerate screen snapshots: \(error.localizedDescription)")
            return [:]
        }
    }

    private func captureRegionWithScreenCaptureKit(_ rectInScreen: CGRect, on screen: NSScreen) async -> CGImage? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }

            let ownPID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

            // sourceRect is display-local with a top-left origin, in points.
            let localX = rectInScreen.origin.x - screen.frame.origin.x
            let localYFromTop = screen.frame.height - (rectInScreen.origin.y - screen.frame.origin.y) - rectInScreen.height

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(
                x: localX, y: localYFromTop, width: rectInScreen.width, height: rectInScreen.height)
            configuration.width = Int(rectInScreen.width * screen.backingScaleFactor)
            configuration.height = Int(rectInScreen.height * screen.backingScaleFactor)
            configuration.showsCursor = false
            configuration.captureResolution = .best

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            AppLogger.capture.error("SCScreenshotManager capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func captureRegionWithCLI(_ rectInScreen: CGRect, on screen: NSScreen) async -> CGImage? {
        let rect = convertToCaptureRect(selectionRectInScreen: rectInScreen, screen: screen)
        guard rect.width > 0, rect.height > 0 else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let success = await runScreenCapture(rectInScreen: rect, outputPath: tempURL.path)
        guard success,
            let imageData = try? Data(contentsOf: tempURL, options: .mappedIfSafe),
            let image = Self.loadImage(from: imageData)
        else {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }

        try? FileManager.default.removeItem(at: tempURL)
        return image
    }

    /// Capture and save directly to a file
    /// - Parameter outputPath: Path where to save the image
    /// - Returns: True if capture was successful
    func captureToFile(outputPath: String) async -> Bool {
        return await runScreenCapture(outputPath: outputPath)
    }

    // MARK: - Private Methods

    private func runScreenCapture(outputPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive mode
            // -s: only allow selection (not fullscreen/window)
            // -x: no sound
            process.arguments = ["-i", "-s", "-x", outputPath]

            process.terminationHandler = { process in
                // Check if file was created (user didn't cancel)
                let fileExists = FileManager.default.fileExists(atPath: outputPath)
                continuation.resume(returning: process.terminationStatus == 0 && fileExists)
            }

            do {
                try process.run()
            } catch {
                AppLogger.capture.error("Failed to run screencapture: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    private func runScreenCapture(rectInScreen: CGRect, outputPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            let rectArgument = String(
                format: "-R%.0f,%.0f,%.0f,%.0f",
                rectInScreen.minX,
                rectInScreen.minY,
                rectInScreen.width,
                rectInScreen.height
            )
            process.arguments = [rectArgument, "-x", outputPath]

            process.terminationHandler = { process in
                let fileExists = FileManager.default.fileExists(atPath: outputPath)
                continuation.resume(returning: process.terminationStatus == 0 && fileExists)
            }

            do {
                try process.run()
            } catch {
                AppLogger.capture.error("Failed to run screencapture: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    private func convertToCaptureRect(selectionRectInScreen: CGRect, screen: NSScreen) -> CGRect {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return selectionRectInScreen
        }

        let displayBounds = CGDisplayBounds(displayID)
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

    private nonisolated static func loadImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        )
    }
}
