//
//  GifExportLoadingOverlay.swift
//  PeekOCR
//
//  Full-screen loading overlay shown while exporting a GIF.
//

import SwiftUI

/// Full-screen loading overlay displayed during GIF export.
struct GifExportLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Exportando GIF…")
                    .font(.headline)
                Text("Esto puede tardar unos segundos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    GifExportLoadingOverlay()
        .frame(width: 720, height: 520)
}

