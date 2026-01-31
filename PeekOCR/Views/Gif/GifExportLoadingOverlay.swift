//
//  GifExportLoadingOverlay.swift
//  PeekOCR
//
//  Full-screen overlay shown while exporting a GIF or video.
//

import SwiftUI

/// Overlay state shown during clip export.
enum ClipExportOverlayState: Equatable {
    case exporting(format: ClipExportFormat)
    case success(format: ClipExportFormat)
}

/// Full-screen overlay displayed during clip export.
struct ClipExportOverlay: View {
    let state: ClipExportOverlayState

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                switch state {
                case .exporting(let format):
                    ProgressView()
                        .controlSize(.large)
                    Text(exportTitle(format: format))
                        .font(.headline)
                    Text("Esto puede tardar unos segundos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .success(let format):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.green)
                    Text(successTitle(format: format))
                        .font(.headline)
                }
            }
            .padding(20)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func exportTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "Exportando GIF…"
        case .video:
            return "Exportando Video…"
        }
    }

    private func successTitle(format: ClipExportFormat) -> String {
        switch format {
        case .gif:
            return "GIF listo"
        case .video:
            return "Video listo"
        }
    }
}

#Preview {
    ClipExportOverlay(state: .exporting(format: .gif))
        .frame(width: 720, height: 520)
}
