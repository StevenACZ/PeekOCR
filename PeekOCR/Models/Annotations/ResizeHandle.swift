//
//  ResizeHandle.swift
//  PeekOCR
//
//  Enum representing the eight resize handle positions around a selection.
//

import Foundation

/// Resize handles for annotation selection bounding box
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}
