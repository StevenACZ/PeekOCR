//
//  AppLogger.swift
//  PeekOCR
//
//  Centralized logging utility using Apple's OSLog framework.
//  Provides structured logging across different app subsystems.
//

import os.log

/// AppLogger provides a centralized logging interface for the PeekOCR application.
/// It uses Apple's OSLog framework for efficient, privacy-aware logging that integrates
/// with Console.app and other system tools.
///
/// Usage:
/// ```swift
/// AppLogger.ocr.debug("Starting text recognition")
/// AppLogger.capture.info("Screenshot captured successfully")
/// AppLogger.history.warning("Cache approaching limit")
/// AppLogger.annotation.error("Failed to save annotation")
/// ```
enum AppLogger {

    // MARK: - Subsystem Identifier

    /// The app's bundle identifier used as the logging subsystem
    private static let subsystem = "com.peekocr"

    // MARK: - Category Loggers

    /// Logger for OCR (Optical Character Recognition) operations.
    /// Use for text recognition, language detection, and OCR processing events.
    static let ocr = Logger(subsystem: subsystem, category: "ocr")

    /// Logger for screen capture operations.
    /// Use for screenshot capture, image processing, and capture permission events.
    static let capture = Logger(subsystem: subsystem, category: "capture")

    /// Logger for history management operations.
    /// Use for saving, loading, deleting, and managing OCR history entries.
    static let history = Logger(subsystem: subsystem, category: "history")

    /// Logger for annotation editor operations.
    /// Use for drawing, text annotations, shapes, and editor state changes.
    static let annotation = Logger(subsystem: subsystem, category: "annotation")

    /// Logger for UI-related events.
    /// Use for view lifecycle, user interactions, and interface state changes.
    static let ui = Logger(subsystem: subsystem, category: "ui")

    // MARK: - Convenience Helper Functions

    /// Logs a debug message to the specified category.
    /// Debug messages are intended for development and troubleshooting.
    /// - Parameters:
    ///   - message: The message to log
    ///   - logger: The category logger to use
    static func debug(_ message: String, logger: Logger) {
        logger.debug("\(message, privacy: .public)")
    }

    /// Logs an informational message to the specified category.
    /// Info messages indicate normal application flow and milestones.
    /// - Parameters:
    ///   - message: The message to log
    ///   - logger: The category logger to use
    static func info(_ message: String, logger: Logger) {
        logger.info("\(message, privacy: .public)")
    }

    /// Logs a warning message to the specified category.
    /// Warning messages indicate potential issues that don't prevent operation.
    /// - Parameters:
    ///   - message: The message to log
    ///   - logger: The category logger to use
    static func warning(_ message: String, logger: Logger) {
        logger.warning("\(message, privacy: .public)")
    }

    /// Logs an error message to the specified category.
    /// Error messages indicate failures that may impact functionality.
    /// - Parameters:
    ///   - message: The message to log
    ///   - logger: The category logger to use
    static func error(_ message: String, logger: Logger) {
        logger.error("\(message, privacy: .public)")
    }

    /// Logs a fault message to the specified category.
    /// Fault messages indicate critical errors that should never occur.
    /// - Parameters:
    ///   - message: The message to log
    ///   - logger: The category logger to use
    static func fault(_ message: String, logger: Logger) {
        logger.fault("\(message, privacy: .public)")
    }
}
