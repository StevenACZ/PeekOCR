//
//  TranslationService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import NaturalLanguage

/// Service for translating text
/// Note: Apple's Translation framework requires macOS 15.0+ and SwiftUI context
/// For macOS 13-14, we provide language detection only
final class TranslationService {
    static let shared = TranslationService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Translate text from source to target language
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceLanguage: Source language code (e.g., "en")
    ///   - targetLanguage: Target language code (e.g., "es")
    /// - Returns: Translated text or original if translation unavailable
    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async -> String {
        // For macOS 13-14, Translation framework isn't available
        // Detect the actual language of the text
        let detectedLanguage = detectLanguage(for: text)
        
        // If text is already in target language, return as-is
        if detectedLanguage == targetLanguage {
            return text
        }
        
        // Return original text - translation requires macOS 15+ with SwiftUI context
        // The app will show the original text in clipboard
        return text
    }
    
    /// Detect the language of the given text
    /// - Parameter text: Text to analyze
    /// - Returns: Language code or nil
    func detectLanguage(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }
    
    /// Check if translation is available
    /// Translation framework requires macOS 15.0+
    var isTranslationAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }
}
