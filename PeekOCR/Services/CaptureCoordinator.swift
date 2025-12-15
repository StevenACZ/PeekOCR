//
//  CaptureCoordinator.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import SwiftUI
import Combine

/// Coordinates the capture flow: overlay → capture → OCR → clipboard
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()
    
    // MARK: - Properties
    
    @Published private(set) var isCapturing = false
    private var overlayWindows: [CaptureOverlayWindow] = []
    private var shouldTranslate = false
    
    // MARK: - Services
    
    private let screenCaptureService = ScreenCaptureService.shared
    private let ocrService = OCRService.shared
    private let pasteboardService = PasteboardService.shared
    private let historyManager = HistoryManager.shared
    private let settings = AppSettings.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start the capture flow
    /// - Parameter withTranslation: Whether to translate the captured text
    func startCapture(withTranslation: Bool) {
        guard !isCapturing else { return }
        
        shouldTranslate = withTranslation
        isCapturing = true
        
        showOverlay()
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
            
            // Process with OCR
            let result = await ocrService.processImage(image)
            
            switch result {
            case .text(let text):
                await handleTextResult(text)
            case .qrCode(let content):
                await handleQRResult(content)
            case .empty:
                // Nothing found
                break
            case .error:
                // Handle error silently
                break
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
    
    private func handleTextResult(_ text: String) async {
        var finalText = text
        
        // Translate if needed
        if shouldTranslate {
            finalText = await TranslationService.shared.translate(
                text: text,
                from: settings.sourceLanguage,
                to: settings.targetLanguage
            )
        }
        
        // Copy to clipboard
        pasteboardService.copy(finalText)
        
        // Add to history
        let item = CaptureItem(
            text: finalText,
            captureType: .text,
            wasTranslated: shouldTranslate,
            originalText: shouldTranslate ? text : nil
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
