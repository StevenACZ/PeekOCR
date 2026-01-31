//
//  GifClipSidebarView+Preview.swift
//  PeekOCR
//
//  Preview-only scaffolding for the clip sidebar view.
//

import SwiftUI

#Preview {
    GifClipSidebarPreviewWrapper()
        .frame(height: 560)
}

private struct GifClipSidebarPreviewWrapper: View {
    @State private var exportFormat: ClipExportFormat = .gif
    @State private var gifOptions = GifExportOptions()
    @State private var videoOptions = VideoExportOptions()

    var body: some View {
        GifClipSidebarView(
            exportFormat: $exportFormat,
            gifOptions: $gifOptions,
            videoOptions: $videoOptions,
            outputDirectory: URL(fileURLWithPath: "/Users/steven/Downloads"),
            selectionDurationSeconds: 4.2,
            sourceNominalFps: 60,
            exportDisabledMessage: nil
        )
        .padding()
    }
}
