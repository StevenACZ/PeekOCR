//
//  HistoryManager.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import Combine

/// Manages the history of captured items
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    // MARK: - Properties
    
    @Published private(set) var items: [CaptureItem] = []
    
    private let maxItems = 6
    private let storageKey = "captureHistory"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        loadItems()
    }
    
    // MARK: - Public Methods
    
    /// Add a new item to the history
    /// - Parameter item: The capture item to add
    func addItem(_ item: CaptureItem) {
        var updatedItems = items
        
        // Insert at the beginning
        updatedItems.insert(item, at: 0)
        
        // Keep only the max number of items
        if updatedItems.count > maxItems {
            updatedItems = Array(updatedItems.prefix(maxItems))
        }
        
        items = updatedItems
        saveItems()
    }
    
    /// Remove an item from history
    /// - Parameter item: The item to remove
    func removeItem(_ item: CaptureItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    /// Clear all history
    func clearHistory() {
        items.removeAll()
        saveItems()
    }
    
    /// Copy an item to clipboard again
    /// - Parameter item: The item to copy
    func copyItem(_ item: CaptureItem) {
        PasteboardService.shared.copy(item.text)
    }
    
    // MARK: - Private Methods
    
    private func loadItems() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CaptureItem].self, from: data) else {
            return
        }
        items = decoded
    }
    
    private func saveItems() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: storageKey)
    }
}
