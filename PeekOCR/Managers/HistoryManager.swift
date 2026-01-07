//
//  HistoryManager.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation
import Combine
import os.log

/// Manages the history of captured items
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    // MARK: - Properties

    @Published private(set) var items: [CaptureItem] = []

    private let maxItems: Int
    private let storageKey: String
    private let defaults: UserDefaults

    // MARK: - Initialization

    private init() {
        self.maxItems = Constants.History.maxItems
        self.storageKey = "captureHistory"
        self.defaults = UserDefaults.standard
        loadItems()
    }

    /// Internal initializer for testing with dependency injection
    /// - Parameters:
    ///   - defaults: UserDefaults instance to use for storage
    ///   - storageKey: Key to use for storing history data
    ///   - maxItems: Maximum number of items to keep in history
    init(defaults: UserDefaults, storageKey: String, maxItems: Int = Constants.History.maxItems) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxItems = maxItems
        loadItems()
    }

    // MARK: - Public Methods

    /// Add a new item to the history
    /// - Parameter item: The capture item to add
    func addItem(_ item: CaptureItem) {
        // Validate item before adding
        guard !item.text.isEmpty else {
            AppLogger.history.warning("Attempted to add item with empty text, skipping")
            return
        }

        var updatedItems = items

        // Insert at the beginning
        updatedItems.insert(item, at: 0)

        // Keep only the max number of items
        if updatedItems.count > maxItems {
            let removedCount = updatedItems.count - maxItems
            updatedItems = Array(updatedItems.prefix(maxItems))
            AppLogger.history.debug("Trimmed \(removedCount) old items to maintain max limit of \(self.maxItems)")
        }

        items = updatedItems
        AppLogger.history.debug("Added new item to history (id: \(item.id.uuidString), text length: \(item.text.count))")
        saveItems()
    }

    /// Remove an item from history
    /// - Parameter item: The item to remove
    func removeItem(_ item: CaptureItem) {
        let previousCount = items.count
        items.removeAll { $0.id == item.id }

        if items.count < previousCount {
            AppLogger.history.debug("Removed item from history (id: \(item.id.uuidString))")
            saveItems()
        } else {
            AppLogger.history.warning("Attempted to remove non-existent item (id: \(item.id.uuidString))")
        }
    }

    /// Clear all history
    func clearHistory() {
        let itemCount = items.count
        items.removeAll()
        AppLogger.history.info("Cleared all history (\(itemCount) items removed)")
        saveItems()
    }

    /// Copy an item to clipboard again
    /// - Parameter item: The item to copy
    func copyItem(_ item: CaptureItem) {
        PasteboardService.shared.copy(item.text)
        AppLogger.history.debug("Copied item to clipboard (id: \(item.id.uuidString))")
    }

    // MARK: - Private Methods

    private func loadItems() {
        guard let data = defaults.data(forKey: storageKey) else {
            AppLogger.history.debug("No existing history data found in UserDefaults")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([CaptureItem].self, from: data)
            items = decoded
            AppLogger.history.info("Loaded \(decoded.count) items from history")
        } catch let error as DecodingError {
            handleDecodingError(error, data: data)
        } catch {
            AppLogger.history.error("Failed to load history: \(error.localizedDescription)")
            // Keep items empty rather than crash
            items = []
        }
    }

    private func saveItems() {
        do {
            let encoded = try JSONEncoder().encode(items)
            defaults.set(encoded, forKey: storageKey)
            AppLogger.history.debug("Saved \(self.items.count) items to UserDefaults (\(encoded.count) bytes)")
        } catch {
            AppLogger.history.error("Failed to save history: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling

    private func handleDecodingError(_ error: DecodingError, data: Data) {
        switch error {
        case .typeMismatch(let type, let context):
            AppLogger.history.warning("History data type mismatch - expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .valueNotFound(let type, let context):
            AppLogger.history.warning("History data missing value - expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .keyNotFound(let key, let context):
            AppLogger.history.warning("History data missing key '\(key.stringValue)', path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .dataCorrupted(let context):
            AppLogger.history.warning("History data corrupted: \(context.debugDescription)")
        @unknown default:
            AppLogger.history.warning("Unknown decoding error: \(error.localizedDescription)")
        }

        // Log data size for debugging
        AppLogger.history.debug("Corrupted data size: \(data.count) bytes")

        // Clear corrupted data to prevent repeated failures
        defaults.removeObject(forKey: storageKey)
        AppLogger.history.info("Cleared corrupted history data from UserDefaults")
        items = []
    }
}
