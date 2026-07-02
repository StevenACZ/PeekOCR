//
//  AnnotationTool.swift
//  PeekOCR
//
//  Defines available annotation tools (arrow, text, freehand, etc.) with their properties.
//

import Foundation

/// Available annotation tools for drawing on screenshots
enum AnnotationTool: String, CaseIterable {
    case select
    case arrow
    case text
    case freehand
    case rectangle
    case oval

    /// SF Symbol name for the tool
    var iconName: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .freehand: return "pencil.line"
        case .rectangle: return "rectangle"
        case .oval: return "oval"
        }
    }

    /// Display name for the tool
    var displayName: String {
        switch self {
        case .select: return "annotation.tool_select".localized
        case .arrow: return "annotation.tool_arrow".localized
        case .text: return "annotation.tool_text".localized
        case .freehand: return "annotation.tool_freehand".localized
        case .rectangle: return "annotation.tool_rectangle".localized
        case .oval: return "annotation.tool_oval".localized
        }
    }

    /// Keyboard shortcut (0-5)
    var shortcutKey: String {
        switch self {
        case .select: return "0"
        case .arrow: return "1"
        case .text: return "2"
        case .freehand: return "3"
        case .rectangle: return "4"
        case .oval: return "5"
        }
    }
}
