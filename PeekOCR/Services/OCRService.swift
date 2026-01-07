//
//  OCRService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Vision
import AppKit
import os.log

// MARK: - OCR Error Types

/// Specific error types for OCR operations
enum OCRError: Error, LocalizedError {
    case noImageData
    case recognitionFailed(Error)
    case noTextFound
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noImageData:
            return "No image data provided for OCR processing"
        case .recognitionFailed(let underlyingError):
            return "Text recognition failed: \(underlyingError.localizedDescription)"
        case .noTextFound:
            return "No text was found in the image"
        case .cancelled:
            return "OCR operation was cancelled"
        }
    }
}

/// Result type for OCR processing
enum OCRResult {
    case text(String)
    case qrCode(String)
    case empty
    case error(Error)
}

/// Service for performing OCR and QR code detection using Vision framework
final class OCRService {
    static let shared = OCRService()

    // MARK: - Initialization

    private init() {
        AppLogger.ocr.debug("OCRService initialized")
    }

    // MARK: - Public Methods

    /// Process an image for text and QR codes
    /// - Parameter image: The image to process
    /// - Returns: OCR result containing extracted text or QR content
    func processImage(_ image: CGImage) async -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.ocr.debug("Starting image processing (\(image.width)x\(image.height))")

        // First, try to detect QR codes
        if let qrContent = await detectQRCode(in: image) {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            AppLogger.ocr.info("QR code detected successfully in \(String(format: "%.2f", elapsed))s")
            return .qrCode(qrContent)
        }

        // If no QR code, perform text recognition
        let text = await recognizeText(in: image)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        if text.isEmpty {
            AppLogger.ocr.warning("No text found in image after \(String(format: "%.2f", elapsed))s")
            return .empty
        }

        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        AppLogger.ocr.info("Text recognition completed: \(wordCount) words in \(String(format: "%.2f", elapsed))s")

        return .text(text)
    }

    /// Recognize text in an image
    /// - Parameter image: The image to process
    /// - Returns: Recognized text string
    func recognizeText(in image: CGImage) async -> String {
        AppLogger.ocr.debug("Starting text recognition request")

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    AppLogger.ocr.error("Text recognition request failed: \(error.localizedDescription)")
                    continuation.resume(returning: "")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    AppLogger.ocr.warning("No text observations returned from Vision request")
                    continuation.resume(returning: "")
                    return
                }

                if observations.isEmpty {
                    AppLogger.ocr.debug("Vision request completed with zero observations")
                    continuation.resume(returning: "")
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                AppLogger.ocr.debug("Extracted \(observations.count) text observations")
                continuation.resume(returning: text)
            }

            // Configure request for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE", "pt-BR", "it-IT"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                AppLogger.ocr.error("Failed to perform text recognition: \(error.localizedDescription)")
                continuation.resume(returning: "")
            }
        }
    }

    /// Detect QR codes in an image
    /// - Parameter image: The image to process
    /// - Returns: QR code content if found, nil otherwise
    func detectQRCode(in image: CGImage) async -> String? {
        AppLogger.ocr.debug("Starting QR code detection request")

        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    AppLogger.ocr.error("Barcode detection request failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    AppLogger.ocr.debug("No barcode observations returned from Vision request")
                    continuation.resume(returning: nil)
                    return
                }

                // Get first QR code payload
                let qrContent = observations
                    .first(where: { $0.symbology == .qr })?
                    .payloadStringValue

                if qrContent != nil {
                    AppLogger.ocr.debug("QR code payload extracted successfully")
                } else if !observations.isEmpty {
                    let symbologies = observations.map { $0.symbology.rawValue }.joined(separator: ", ")
                    AppLogger.ocr.debug("Found barcodes but no QR codes: \(symbologies)")
                } else {
                    AppLogger.ocr.debug("No barcodes detected in image")
                }

                continuation.resume(returning: qrContent)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                AppLogger.ocr.error("Failed to perform barcode detection: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
}
