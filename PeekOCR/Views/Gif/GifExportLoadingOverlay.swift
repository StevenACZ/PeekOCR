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

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            GifClipActionFeedbackView(
                feedback: feedback,
                layout: .prominent
            )
            .frame(maxWidth: 340)
            .padding(24)
        }
    }

    private var feedback: GifClipActionFeedback {
        switch state {
        case .exporting(let format, let destinationName):
            return GifClipActionFeedback(
                tone: .progress,
                title: exportTitle(format: format),
                message: "Guardando en \(destinationName). Esto puede tardar unos segundos.",
                badgeText: exportBadge(format: format)
            )
        case .success(let format, let destinationName):
            return GifClipActionFeedback(
                tone: .success,
                title: successTitle(format: format),
                message: "Archivo listo en \(destinationName).",
                badgeText: exportBadge(format: format)
            )
        }
    }

    private func exportTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "Exportando GIF…"
        case .video:
            return "Exportando MP4…"
        }
    }

    private func successTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "GIF listo"
        case .video:
            return "MP4 listo"
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
    ClipExportOverlay(state: .exporting(format: .gif, destinationName: "Descargas"))
        .frame(width: 720, height: 520)
}
