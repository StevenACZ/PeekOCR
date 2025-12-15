//
//  SupportedLanguage.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation

/// Supported languages for translation
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case italian = "it"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .italian: return "Italiano"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .portuguese: return "🇧🇷"
        case .italian: return "🇮🇹"
        }
    }
    
    var fullDisplayName: String {
        "\(flag) \(displayName)"
    }
    
    static func from(code: String) -> SupportedLanguage? {
        return SupportedLanguage.allCases.first { $0.rawValue == code }
    }
}
