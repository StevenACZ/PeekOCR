//
//  Constants.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Foundation

/// App-wide constants
enum Constants {
    /// UI-related constants
    enum UI {
        /// Width of the menu bar popover
        static let popoverWidth: CGFloat = 320

        /// Maximum height for the history scroll view
        static let historyMaxHeight: CGFloat = 180

        /// Standard horizontal padding
        static let horizontalPadding: CGFloat = 16

        /// Standard vertical padding
        static let verticalPadding: CGFloat = 12

        /// Small vertical padding
        static let smallVerticalPadding: CGFloat = 8
    }

    /// History-related constants
    enum History {
        /// Maximum number of items to keep in history
        static let maxItems: Int = 6

        /// Maximum characters to display in preview text
        static let maxPreviewLength: Int = 50
    }

    /// App information
    enum App {
        static let version = "1.3.0"
        static let minimumOSVersion = "macOS 13.0+"
    }

    /// GIF capture/export defaults
    enum Gif {
        static let defaultMaxDurationSeconds = 10
        static let maxDurationRange = 3...60
        static let trimStepSeconds: Double = 0.1
        static let minimumClipDurationSeconds: Double = 3.0
    }
}
