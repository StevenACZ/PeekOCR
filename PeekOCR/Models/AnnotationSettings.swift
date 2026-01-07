//
//  AnnotationSettings.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI
import Combine

/// Persistent settings for annotation tools
final class AnnotationSettings: ObservableObject {
    static let shared = AnnotationSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let defaultStrokeWidth = "annotationDefaultStrokeWidth"
        static let defaultFontSize = "annotationDefaultFontSize"
        static let defaultColorIndex = "annotationDefaultColorIndex"
    }

    // MARK: - Default Values

    struct Defaults {
        static let strokeWidth: CGFloat = 3.0
        static let fontSize: CGFloat = 16.0
        static let colorIndex: Int = 0
    }

    // MARK: - Constraints

    struct Constraints {
        static let strokeWidthRange: ClosedRange<CGFloat> = 1.0...10.0
        static let fontSizeRange: ClosedRange<CGFloat> = 12.0...48.0
        static let colorIndexRange: ClosedRange<Int> = 0...7
    }

    // MARK: - Color Palette

    /// Available colors for annotations
    static let colorPalette: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple,
        .pink,
        .white
    ]

    // MARK: - Published Properties

    /// Default stroke width for annotations (1.0 - 10.0)
    @Published var defaultStrokeWidth: CGFloat {
        didSet {
            let clamped = defaultStrokeWidth.clamped(to: Constraints.strokeWidthRange)
            if clamped != defaultStrokeWidth {
                defaultStrokeWidth = clamped
            }
            defaults.set(Double(defaultStrokeWidth), forKey: Keys.defaultStrokeWidth)
        }
    }

    /// Default font size for text annotations (12.0 - 48.0)
    @Published var defaultFontSize: CGFloat {
        didSet {
            let clamped = defaultFontSize.clamped(to: Constraints.fontSizeRange)
            if clamped != defaultFontSize {
                defaultFontSize = clamped
            }
            defaults.set(Double(defaultFontSize), forKey: Keys.defaultFontSize)
        }
    }

    /// Default color index (0-7 for the color palette)
    @Published var defaultColorIndex: Int {
        didSet {
            let clamped = defaultColorIndex.clamped(to: Constraints.colorIndexRange)
            if clamped != defaultColorIndex {
                defaultColorIndex = clamped
            }
            defaults.set(defaultColorIndex, forKey: Keys.defaultColorIndex)
        }
    }

    // MARK: - Computed Properties

    /// The default color based on the color index
    var defaultColor: Color {
        guard defaultColorIndex >= 0 && defaultColorIndex < Self.colorPalette.count else {
            return Self.colorPalette[0]
        }
        return Self.colorPalette[defaultColorIndex]
    }

    // MARK: - Initialization

    private init() {
        // Load stroke width
        let savedStrokeWidth = defaults.double(forKey: Keys.defaultStrokeWidth)
        if savedStrokeWidth > 0 {
            self.defaultStrokeWidth = CGFloat(savedStrokeWidth).clamped(to: Constraints.strokeWidthRange)
        } else {
            self.defaultStrokeWidth = Defaults.strokeWidth
        }

        // Load font size
        let savedFontSize = defaults.double(forKey: Keys.defaultFontSize)
        if savedFontSize > 0 {
            self.defaultFontSize = CGFloat(savedFontSize).clamped(to: Constraints.fontSizeRange)
        } else {
            self.defaultFontSize = Defaults.fontSize
        }

        // Load color index
        if defaults.object(forKey: Keys.defaultColorIndex) != nil {
            let savedIndex = defaults.integer(forKey: Keys.defaultColorIndex)
            self.defaultColorIndex = savedIndex.clamped(to: Constraints.colorIndexRange)
        } else {
            self.defaultColorIndex = Defaults.colorIndex
        }
    }

    // MARK: - Public Methods

    /// Resets all settings to defaults
    func resetToDefaults() {
        defaultStrokeWidth = Defaults.strokeWidth
        defaultFontSize = Defaults.fontSize
        defaultColorIndex = Defaults.colorIndex
    }
}

// MARK: - Comparable Clamping Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
