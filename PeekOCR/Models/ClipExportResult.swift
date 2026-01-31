//
//  ClipExportResult.swift
//  PeekOCR
//
//  Result type returned by the clip editor after exporting.
//

import Foundation

/// Result returned by the clip editor after an export completes.
struct ClipExportResult: Equatable {
    let url: URL
    let format: ClipExportFormat
}

