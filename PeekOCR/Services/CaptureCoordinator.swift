//
//  CaptureCoordinator.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI
import Combine

/// Capture mode enumeration
enum CaptureMode {
    case ocr
    case translate
    case screenshot
}

/// Coordinates the capture flow: native capture → process → clipboard/save
/// Uses macOS native screencapture for all capture modes
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()
    
    // MARK: - Properties
    
    @Published private(set) var isCapturing = false
    private var currentMode: CaptureMode = .ocr
    
    // MARK: - Services
    
    private let nativeScreenCapture = NativeScreenCaptureService.shared
    private let ocrService = OCRService.shared
    private let pasteboardService = PasteboardService.shared
    private let screenshotService = ScreenshotService.shared
    private let historyManager = HistoryManager.shared
    private let settings = AppSettings.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start the capture flow
    /// - Parameter mode: The capture mode (OCR, translate, or screenshot)
    func startCapture(mode: CaptureMode) {
        guard !isCapturing else { return }
        
        currentMode = mode
        isCapturing = true
        
        // Use native macOS screencapture for all modes
        // This provides a better user experience with no double-click issues
        Task { @MainActor in
            await captureWithNativeScreenshot()
        }
    }
    
    /// Legacy method for backward compatibility
    func startCapture(withTranslation: Bool) {
        startCapture(mode: withTranslation ? .translate : .ocr)
    }
    
    /// Cancel the current capture
    func cancelCapture() {
        isCapturing = false
    }
    
    // MARK: - Private Methods
    
    /// Use native macOS screencapture for all capture modes
    /// This provides better UX and Retina resolution captures
    private func captureWithNativeScreenshot() async {
        // Use native screencapture command
        guard let image = await nativeScreenCapture.captureInteractive() else {
            // User cancelled or capture failed
            isCapturing = false
            return
        }
        
        // Process based on mode
        switch currentMode {
        case .ocr:
            await processOCR(image: image)
        case .translate:
            await processTranslate(image: image)
        case .screenshot:
            await processScreenshot(image: image)
        }
        
        isCapturing = false
    }
    
    // MARK: - OCR Processing
    
    private func processOCR(image: CGImage) async {
        let result = await ocrService.processImage(image)
        
        switch result {
        case .text(let text):
            await handleTextResult(text, translated: false)
        case .qrCode(let content):
            await handleQRResult(content)
        case .empty, .error:
            break
        }
    }
    
    // MARK: - Translation Processing
    
    private func processTranslate(image: CGImage) async {
        let result = await ocrService.processImage(image)
        
        switch result {
        case .text(let text):
            let translatedText = await TranslationService.shared.translate(
                text: text,
                from: settings.sourceLanguage,
                to: settings.targetLanguage
            )
            await handleTextResult(translatedText, translated: true, originalText: text)
        case .qrCode(let content):
            await handleQRResult(content)
        case .empty, .error:
            break
        }
    }
    
    // MARK: - Screenshot Processing
    
    private func processScreenshot(image: CGImage) async {
        // Process and save the screenshot
        let savedURL = await screenshotService.processScreenshot(image)
        
        // Optionally add to history (as a note that screenshot was taken)
        let displayText: String
        if let url = savedURL {
            displayText = "📷 " + url.lastPathComponent
        } else {
            displayText = "📷 Captura copiada al portapapeles"
        }
        
        let item = CaptureItem(
            text: displayText,
            captureType: .text,
            wasTranslated: false,
            originalText: nil
        )
        historyManager.addItem(item)
    }
    
    // MARK: - Result Handlers
    
    private func handleTextResult(_ text: String, translated: Bool, originalText: String? = nil) async {
        // Copy to clipboard
        pasteboardService.copy(text)
        
        // Add to history
        let item = CaptureItem(
            text: text,
            captureType: .text,
            wasTranslated: translated,
            originalText: originalText
        )
        historyManager.addItem(item)
    }
    
    private func handleQRResult(_ content: String) async {
        // Copy to clipboard
        pasteboardService.copy(content)
        
        // Add to history
        let item = CaptureItem(
            text: content,
            captureType: .qrCode
        )
        historyManager.addItem(item)
    }
}
