//
//  GifExportLoadingOverlay.swift
//  PeekOCR
//
//  Full-screen overlay shown while exporting a GIF or video.
//

import SwiftUI

/// Overlay state shown during clip export.
enum ClipExportOverlayState: Equatable {
    case exporting(format: ClipExportFormat, destinationName: String)
    case success(format: ClipExportFormat, destinationName: String)
}

/// Full-screen overlay displayed during clip export.
struct ClipExportOverlay: View {
    let state: ClipExportOverlayState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            GifClipActionFeedbackView(
                feedback: feedback,
                layout: .prominent
            )
            .frame(maxWidth: 360)
            .padding(24)
            .scaleEffect(isPresented || reduceMotion ? 1 : 0.9)
            .opacity(isPresented ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.78), value: isPresented)
        }
        .onAppear { isPresented = true }
    }

    private var feedback: GifClipActionFeedback {
        switch state {
        case .exporting(let format, let destinationName):
            return GifClipActionFeedback(
                tone: .progress,
                title: exportTitle(format: format),
                message: "clip_editor.export_saving_message".localized(destinationName),
                badgeText: exportBadge(format: format)
            )
        case .success(let format, let destinationName):
            return GifClipActionFeedback(
                tone: .success,
                title: successTitle(format: format),
                message: "clip_editor.export_ready_message".localized(destinationName),
                badgeText: exportBadge(format: format)
            )
        }
    }

    private func exportTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "clip_editor.exporting_gif".localized
        case .video:
            return "clip_editor.exporting_mp4".localized
        }
    }

    private func successTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "clip_editor.gif_ready".localized
        case .video:
            return "clip_editor.mp4_ready".localized
        }
    }

    private func exportBadge(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "GIF"
        case .video:
            return "MP4"
        }
    }
}

#Preview {
    ClipExportOverlay(state: .exporting(format: .gif, destinationName: "common.downloads".localized))
        .frame(width: 720, height: 520)
}
