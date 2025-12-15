//
//  TranslationService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import NaturalLanguage

#if canImport(Translation)
import Translation
#endif

/// Service for translating text
/// Uses Apple's Translation framework
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
        // If same language, return as-is
        if sourceLanguage == targetLanguage {
            return text
        }
        
        // Use Translation framework (macOS 26+)
        if #available(macOS 26.0, *) {
            do {
                let result = try await translateWithFramework(
                    text: text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                return result
            } catch {
                print("Translation error: \(error.localizedDescription)")
                return text
            }
        }
        
        // For older macOS, return original text
        return text
    }
    
    /// Translate using Apple's Translation framework (macOS 26+)
    @available(macOS 26.0, *)
    private func translateWithFramework(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String {
        // Create language objects
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        
        // Check availability first
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)
        
        switch status {
        case .installed:
            // Language is installed, use direct initialization
            let session = try TranslationSession(installedSource: source, target: target)
            let response = try await session.translate(text)
            return response.targetText
            
        case .supported:
            // Language is supported but not installed
            print("Translation language pack not installed. Please enable in System Settings > Translation.")
            return text
            
        case .unsupported:
            print("Translation not supported for \(sourceLanguage) to \(targetLanguage)")
            return text
            
        @unknown default:
            return text
        }
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
    var isTranslationAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Check if a specific language pair is available for translation
    @available(macOS 26.0, *)
    func isLanguagePairAvailable(from source: String, to target: String) async -> Bool {
        let sourceLang = Locale.Language(identifier: source)
        let targetLang = Locale.Language(identifier: target)
        
        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLang, to: targetLang)
        
        return status == .installed
    }
}
