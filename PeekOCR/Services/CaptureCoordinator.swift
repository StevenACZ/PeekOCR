//
//  CaptureCoordinator.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI
import Combine
import os

/// Capture mode enumeration
enum CaptureMode: CustomStringConvertible {
    case ocr
    case screenshot
    case annotatedScreenshot
    case gifClip

    var description: String {
        switch self {
        case .ocr: return "OCR"
        case .screenshot: return "Screenshot"
        case .annotatedScreenshot: return "Annotated Screenshot"
        case .gifClip: return "GIF Clip"
        }
    }
}

/// Coordinates the capture flow: native capture -> process -> clipboard/save
/// Uses macOS native screencapture for all capture modes
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()

    // MARK: - Properties

    @Published private(set) var isCapturing = false
    private var currentMode: CaptureMode = .ocr
    private var captureStartTime: CFAbsoluteTime = 0

    // MARK: - Services

    private let nativeScreenCapture = NativeScreenCaptureService.shared
    private let nativeScreenRecording = NativeScreenRecordingService.shared
    private let gifRecordingController = GifRecordingController.shared
    private let ocrService = OCRService.shared
    private let pasteboardService = PasteboardService.shared
    private let screenshotService = ScreenshotService.shared
    private let historyManager = HistoryManager.shared

    // MARK: - Initialization

    private init() {
        AppLogger.capture.debug("CaptureCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Start the capture flow
    /// - Parameter mode: The capture mode (OCR or screenshot)
    func startCapture(mode: CaptureMode) {
        if isCapturing {
            if currentMode == .gifClip, mode == .gifClip {
                AppLogger.capture.info("Stopping GIF recording via hotkey")
                gifRecordingController.stop()
                return
            }
            AppLogger.capture.warning("Capture already in progress, ignoring request for mode: \(mode.description)")
            return
        }

        currentMode = mode
        isCapturing = true
        captureStartTime = CFAbsoluteTimeGetCurrent()

        AppLogger.capture.info("Starting capture - mode: \(mode.description)")

        // Use native macOS screencapture for all modes
        Task { @MainActor in
            switch mode {
            case .gifClip:
                await captureGifClipWithNativeRecorder()
            case .ocr, .screenshot, .annotatedScreenshot:
                await captureWithNativeScreenshot()
            }
        }
    }

    /// Cancel the current capture
    func cancelCapture() {
        let wasCapturing = isCapturing
        isCapturing = false

        if wasCapturing {
            let elapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
            AppLogger.capture.info("Capture cancelled - mode: \(self.currentMode.description), elapsed: \(String(format: "%.2f", elapsed))s")
            if currentMode == .gifClip {
                gifRecordingController.stop()
            }
        } else {
            AppLogger.capture.debug("Cancel called but no capture was in progress")
        }
    }

    // MARK: - Private Methods

    /// Use native macOS screencapture for all capture modes
    private func captureWithNativeScreenshot() async {
        AppLogger.capture.debug("Invoking native screen capture")

        guard let image = await nativeScreenCapture.captureInteractive() else {
            let elapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
            AppLogger.capture.info("Native capture returned nil (user cancelled or failed) - elapsed: \(String(format: "%.2f", elapsed))s")
            isCapturing = false
            return
        }

        AppLogger.capture.debug("Native capture successful - dimensions: \(image.width)x\(image.height)")

        // Process based on mode
        switch currentMode {
        case .ocr:
            AppLogger.capture.debug("Processing as OCR")
            await processOCR(image: image)
        case .screenshot:
            AppLogger.capture.debug("Processing as screenshot")
            await processScreenshot(image: image)
        case .annotatedScreenshot:
            AppLogger.capture.debug("Processing as annotated screenshot")
            await processAnnotatedScreenshot(image: image)
        case .gifClip:
            AppLogger.capture.warning("Unexpected screenshot path for GIF clip mode")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
        AppLogger.capture.info("Capture flow complete - mode: \(self.currentMode.description), total time: \(String(format: "%.2f", elapsed))s")

        isCapturing = false
    }

    // MARK: - OCR Processing

    private func processOCR(image: CGImage) async {
        let ocrStartTime = CFAbsoluteTimeGetCurrent()
        AppLogger.capture.debug("Starting OCR processing")

        let result = await ocrService.processImage(image)
        let ocrElapsed = CFAbsoluteTimeGetCurrent() - ocrStartTime

        switch result {
        case .text(let text):
            AppLogger.capture.info("OCR completed - text extracted (\(text.count) chars) in \(String(format: "%.2f", ocrElapsed))s")
            await handleTextResult(text)
        case .qrCode(let content):
            AppLogger.capture.info("OCR completed - QR code detected (\(content.count) chars) in \(String(format: "%.2f", ocrElapsed))s")
            await handleQRResult(content)
        case .empty:
            AppLogger.capture.info("OCR completed - no text found in \(String(format: "%.2f", ocrElapsed))s")
        case .error:
            AppLogger.capture.error("OCR failed after \(String(format: "%.2f", ocrElapsed))s")
        }
    }

    // MARK: - Screenshot Processing

    private func processScreenshot(image: CGImage) async {
        AppLogger.capture.debug("Starting screenshot processing")

        let savedURL = await screenshotService.processScreenshot(image)

        let displayText: String
        if let url = savedURL {
            displayText = url.lastPathComponent
            AppLogger.capture.info("Screenshot saved: \(url.lastPathComponent)")
        } else {
            displayText = "Captura copiada al portapapeles"
            AppLogger.capture.info("Screenshot copied to clipboard (not saved to file)")
        }

        let item = CaptureItem(
            text: displayText,
            captureType: .screenshot
        )
        historyManager.addItem(item)
        AppLogger.capture.debug("Screenshot added to history")
    }

    // MARK: - Annotated Screenshot Processing

    private func processAnnotatedScreenshot(image: CGImage) async {
        AppLogger.capture.debug("Opening annotation editor")

        // Show the annotation editor and wait for result
        guard let annotatedImage = await AnnotationWindowController.shared.showEditor(with: image) else {
            // User cancelled the annotation editor
            AppLogger.capture.info("Annotation editor cancelled by user")
            return
        }

        AppLogger.capture.info("Annotation editor completed - processing annotated image")

        // Process the annotated image as a regular screenshot
        await processScreenshot(image: annotatedImage)
    }

    // MARK: - GIF Clip Processing

    private func captureGifClipWithNativeRecorder() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.capture.debug("Invoking native screen recording")

        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.capture.info("GIF clip flow finished in \(String(format: "%.2f", elapsed))s")
            isCapturing = false
        }

        let supported = await nativeScreenRecording.supportsInteractiveVideoCapture()
        guard supported else {
            AppLogger.capture.error("screencapture video recording flags are not supported on this OS")
            return
        }

        guard let videoURL = await gifRecordingController.record(maxDurationSeconds: Constants.Gif.maxDurationSeconds) else {
            AppLogger.capture.info("GIF clip recording cancelled")
            return
        }

        let saveDirectory = ScreenshotSettings.shared.saveDirectoryURL
        let gifURL = await GifClipWindowController.shared.showEditor(with: videoURL, saveDirectory: saveDirectory)

        try? FileManager.default.removeItem(at: videoURL)

        guard let gifURL else {
            AppLogger.capture.info("GIF export cancelled")
            return
        }

        AppLogger.capture.info("GIF exported: \(gifURL.lastPathComponent)")
        historyManager.addItem(CaptureItem(text: gifURL.lastPathComponent, captureType: .gif))
    }

    // MARK: - Result Handlers

    private func handleTextResult(_ text: String) async {
        pasteboardService.copy(text)
        AppLogger.capture.debug("Text copied to clipboard")

        let item = CaptureItem(
            text: text,
            captureType: .text
        )
        historyManager.addItem(item)
        AppLogger.capture.debug("Text result added to history")
    }

    private func handleQRResult(_ content: String) async {
        pasteboardService.copy(content)
        AppLogger.capture.debug("QR content copied to clipboard")

        let item = CaptureItem(
            text: content,
            captureType: .qrCode
        )
        historyManager.addItem(item)
        AppLogger.capture.debug("QR result added to history")
    }
}
