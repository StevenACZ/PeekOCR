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

        // Use native macOS screencapture for the fast modes and a custom live overlay for annotated capture.
        Task { @MainActor in
            switch mode {
            case .gifClip:
                await captureGifClipWithNativeRecorder()
            case .annotatedScreenshot:
                await captureAnnotatedScreenshotWithLiveOverlay()
            case .ocr, .screenshot:
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

    /// Use native macOS screencapture for OCR/plain screenshots.
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
        CaptureSoundService.shared.play()
    }

    // MARK: - Annotated Screenshot Processing

    private func processAnnotatedScreenshot(image: CGImage) async {
        AppLogger.capture.debug("Opening annotation editor")

        // Legacy post-capture editor path kept for compatibility/testing.
        guard let annotatedImage = await AnnotationWindowController.shared.showEditor(with: image) else {
            // User cancelled the annotation editor
            AppLogger.capture.info("Annotation editor cancelled by user")
            return
        }

        AppLogger.capture.info("Annotation editor completed - processing annotated image")

        // Process the annotated image as a regular screenshot
        await processScreenshot(image: annotatedImage)
    }

    @MainActor
    private func captureAnnotatedScreenshotWithLiveOverlay() async {
        AppLogger.capture.debug("Opening live annotation overlay")

        let overlayController = LiveAnnotationOverlayWindowController()
        guard let session = await overlayController.runSession() else {
            AppLogger.capture.info("Live annotation overlay cancelled by user")
            isCapturing = false
            return
        }

        // Give the overlay window a beat to disappear before the pixel capture happens.
        try? await Task.sleep(nanoseconds: 120_000_000)

        AppLogger.capture.debug("Capturing selected region from live overlay")
        guard let capturedImage = await nativeScreenCapture.captureRegion(session.selectionRect, on: session.screen) else {
            AppLogger.capture.error("Failed to capture selected region after live overlay")
            isCapturing = false
            return
        }

        let visibleAnnotations = session.annotations.filter { annotation in
            switch annotation.tool {
            case .text:
                return session.selectionRect.contains(annotation.startPoint)
            case .arrow, .highlight:
                return session.selectionRect.intersects(annotation.bounds)
            case .select:
                return false
            }
        }

        let finalImage = LiveAnnotationRenderer.render(
            image: capturedImage,
            selectionRectInScreen: session.selectionRect,
            scaleFactor: session.screen.backingScaleFactor,
            annotations: visibleAnnotations
        ) ?? capturedImage

        AppLogger.capture.info("Live annotation capture completed - processing final image")
        await processScreenshot(image: finalImage)

        let elapsed = CFAbsoluteTimeGetCurrent() - captureStartTime
        AppLogger.capture.info("Capture flow complete - mode: \(self.currentMode.description), total time: \(String(format: "%.2f", elapsed))s")
        isCapturing = false
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

        let clipSettings = GifClipSettings.shared
        guard let videoURL = await gifRecordingController.record(maxDurationSeconds: clipSettings.maxDurationSeconds) else {
            AppLogger.capture.info("GIF clip recording cancelled")
            return
        }

        let saveDirectory = ScreenshotSettings.shared.saveDirectoryURL
        let exportResult = await GifClipWindowController.shared.showEditor(with: videoURL, saveDirectory: saveDirectory)

        try? FileManager.default.removeItem(at: videoURL)

        guard let exportResult else {
            AppLogger.capture.info("Clip export cancelled")
            return
        }

        AppLogger.capture.info("Clip exported: \(exportResult.url.lastPathComponent)")
        historyManager.addItem(CaptureItem(
            text: exportResult.url.lastPathComponent,
            captureType: exportResult.format == .gif ? .gif : .video
        ))
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
