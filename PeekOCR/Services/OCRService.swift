//
//  OCRService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Vision
import AppKit

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
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Process an image for text and QR codes
    /// - Parameter image: The image to process
    /// - Returns: OCR result containing extracted text or QR content
    func processImage(_ image: CGImage) async -> OCRResult {
        // First, try to detect QR codes
        if let qrContent = await detectQRCode(in: image) {
            return .qrCode(qrContent)
        }
        
        // If no QR code, perform text recognition
        let text = await recognizeText(in: image)
        if text.isEmpty {
            return .empty
        }
        
        return .text(text)
    }
    
    /// Recognize text in an image
    /// - Parameter image: The image to process
    /// - Returns: Recognized text string
    func recognizeText(in image: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
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
                continuation.resume(returning: "")
            }
        }
    }
    
    /// Detect QR codes in an image
    /// - Parameter image: The image to process
    /// - Returns: QR code content if found, nil otherwise
    func detectQRCode(in image: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Get first QR code payload
                let qrContent = observations
                    .first(where: { $0.symbology == .qr })?
                    .payloadStringValue
                
                continuation.resume(returning: qrContent)
            }
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
