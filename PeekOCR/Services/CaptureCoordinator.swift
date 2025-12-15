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
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start the capture flow
    /// - Parameter mode: The capture mode (OCR or screenshot)
    func startCapture(mode: CaptureMode) {
        guard !isCapturing else { return }
        
        currentMode = mode
        isCapturing = true
        
        // Use native macOS screencapture for all modes
        Task { @MainActor in
            await captureWithNativeScreenshot()
        }
    }
    
    /// Cancel the current capture
    func cancelCapture() {
        isCapturing = false
    }
    
    // MARK: - Private Methods
    
    /// Use native macOS screencapture for all capture modes
    private func captureWithNativeScreenshot() async {
        guard let image = await nativeScreenCapture.captureInteractive() else {
            isCapturing = false
            return
        }
        
        // Process based on mode
        switch currentMode {
        case .ocr:
            await processOCR(image: image)
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
            await handleTextResult(text)
        case .qrCode(let content):
            await handleQRResult(content)
        case .empty, .error:
            break
        }
    }
    
    // MARK: - Screenshot Processing
    
    private func processScreenshot(image: CGImage) async {
        let savedURL = await screenshotService.processScreenshot(image)
        
        let displayText: String
        if let url = savedURL {
            displayText = url.lastPathComponent
        } else {
            displayText = "Captura copiada al portapapeles"
        }
        
        let item = CaptureItem(
            text: displayText,
            captureType: .screenshot
        )
        historyManager.addItem(item)
    }
    
    // MARK: - Result Handlers
    
    private func handleTextResult(_ text: String) async {
        pasteboardService.copy(text)
        
        let item = CaptureItem(
            text: text,
            captureType: .text
        )
        historyManager.addItem(item)
    }
    
    private func handleQRResult(_ content: String) async {
        pasteboardService.copy(content)
        
        let item = CaptureItem(
            text: content,
            captureType: .qrCode
        )
        historyManager.addItem(item)
    }
}
