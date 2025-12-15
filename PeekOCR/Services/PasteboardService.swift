//
//  PasteboardService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit

/// Service for copying text to the system clipboard
final class PasteboardService {
    static let shared = PasteboardService()
    
    // MARK: - Properties
    
    private let pasteboard = NSPasteboard.general
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Copy text to the clipboard
    /// - Parameter text: The text to copy
    /// - Returns: True if copy was successful
    @discardableResult
    func copy(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
    
    /// Get the current clipboard text
    /// - Returns: The clipboard text or nil
    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    /// Clear the clipboard
    func clear() {
        pasteboard.clearContents()
    }
}
