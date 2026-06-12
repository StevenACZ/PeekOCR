//
//  OCRService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import Vision
import os.log

/// Result type for OCR processing
enum OCRResult {
    case text(String)
    case qrCode(String)
    case empty
    case error(Error)
}

/// Service for performing OCR and QR code detection using the modern Vision API
final class OCRService {
    static let shared = OCRService()

    private nonisolated static let recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "pt-BR", "it-IT"]
        .map(Locale.Language.init(identifier:))

    // MARK: - Initialization

    private init() {
        AppLogger.ocr.debug("OCRService initialized")
    }

    // MARK: - Public Methods

    /// Process an image for text and QR codes. Both detections run in parallel;
    /// a QR hit wins over plain text.
    /// - Parameter image: The image to process
    /// - Returns: OCR result containing extracted text or QR content
    nonisolated func processImage(_ image: CGImage) async -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.ocr.debug("Starting image processing (\(image.width)x\(image.height))")

        async let qrContent = Self.detectQRCode(in: image)
        async let recognizedText = Self.recognizeText(in: image)

        if let qrContent = await qrContent {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.ocr.info("QR code detected successfully in \(String(format: "%.2f", elapsed))s")
            return .qrCode(qrContent)
        }

        let text = await recognizedText
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        if text.isEmpty {
            AppLogger.ocr.warning("No text found in image after \(String(format: "%.2f", elapsed))s")
            return .empty
        }

        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        AppLogger.ocr.info("Text recognition completed: \(wordCount) words in \(String(format: "%.2f", elapsed))s")

        return .text(text)
    }

    // MARK: - Private Methods

    /// Recognize text in an image
    /// - Parameter image: The image to process
    /// - Returns: Recognized text string
    nonisolated private static func recognizeText(in image: CGImage) async -> String {
        AppLogger.ocr.debug("Starting text recognition request")

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = recognitionLanguages

        do {
            let observations = try await request.perform(on: image)
            guard !observations.isEmpty else {
                AppLogger.ocr.debug("Vision request completed with zero observations")
                return ""
            }

            AppLogger.ocr.debug("Extracted \(observations.count) text observations")
            return
                observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        } catch {
            AppLogger.ocr.error("Failed to perform text recognition: \(error.localizedDescription)")
            return ""
        }
    }

    /// Detect QR codes in an image
    /// - Parameter image: The image to process
    /// - Returns: QR code content if found, nil otherwise
    nonisolated private static func detectQRCode(in image: CGImage) async -> String? {
        AppLogger.ocr.debug("Starting QR code detection request")

        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]

        do {
            let observations = try await request.perform(on: image)
            guard let payload = observations.first?.payloadString else {
                AppLogger.ocr.debug("No QR codes detected in image")
                return nil
            }

            AppLogger.ocr.debug("QR code payload extracted successfully")
            return payload
        } catch {
            AppLogger.ocr.error("Failed to perform barcode detection: \(error.localizedDescription)")
            return nil
        }
    }
}
