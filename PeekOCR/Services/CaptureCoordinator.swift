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

/// Coordinates the capture flow: overlay → capture → process → clipboard/save
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()
    
    // MARK: - Properties
    
    @Published private(set) var isCapturing = false
    private var overlayWindows: [CaptureOverlayWindow] = []
    private var currentMode: CaptureMode = .ocr
    
    // MARK: - Services
    
    private let screenCaptureService = ScreenCaptureService.shared
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
        
        showOverlay()
    }
    
    /// Legacy method for backward compatibility
    func startCapture(withTranslation: Bool) {
        startCapture(mode: withTranslation ? .translate : .ocr)
    }
    
    /// Cancel the current capture
    func cancelCapture() {
        hideOverlay()
        isCapturing = false
    }
    
    /// Process a captured region
    /// - Parameter rect: The screen region to process
    func processRegion(_ rect: CGRect) {
        Task { @MainActor in
            hideOverlay()
            
            // Capture the screen region
            guard let image = await screenCaptureService.captureRegion(rect) else {
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
    }
    
    // MARK: - Private Methods
    
    private func showOverlay() {
        // Create overlay windows for each screen
        for screen in NSScreen.screens {
            let window = CaptureOverlayWindow(screen: screen, coordinator: self)
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        
        // Make the app active
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func hideOverlay() {
        for window in overlayWindows {
            window.close()
        }
        overlayWindows.removeAll()
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
