//
//  CaptureItem.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation

/// Represents a captured text or QR item in the history
struct CaptureItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let captureType: CaptureType
    let timestamp: Date
    let wasTranslated: Bool
    let originalText: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        text: String,
        captureType: CaptureType = .text,
        timestamp: Date = Date(),
        wasTranslated: Bool = false,
        originalText: String? = nil
    ) {
        self.id = id
        self.text = text
        self.captureType = captureType
        self.timestamp = timestamp
        self.wasTranslated = wasTranslated
        self.originalText = originalText
    }
    
    // MARK: - Computed Properties
    
    var displayText: String {
        let maxLength = 50
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var icon: String {
        switch captureType {
        case .text:
            return wasTranslated ? "globe" : "doc.text"
        case .qrCode:
            return "qrcode"
        }
    }
}

// MARK: - CaptureType

enum CaptureType: String, Codable {
    case text
    case qrCode
}
