//
//  GifClipSidebarView.swift
//  PeekOCR
//
//  Sidebar for configuring GIF export options and showing output/estimates.
//

import AppKit
import SwiftUI

/// Sidebar content for the GIF clip editor (quality/FPS/size + estimates).
struct GifClipSidebarView: View {
    @Binding var options: GifExportOptions

    let outputDirectory: URL
    let selectionDurationSeconds: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            gifSection
            optimizationSection
            outputSection
            estimationSection
            Spacer()
        }
        .padding(16)
        .frame(width: 320)
        .background(Color.black.opacity(0.14))
    }

    private var header: some View {
        Text("GIF")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var gifSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            rowLabel("Calidad")
            Picker("", selection: Binding(
                get: { options.quality },
                set: { newValue in options.applyQualityPreset(newValue) }
            )) {
                ForEach(GifExportQuality.allCases) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)

            rowLabel("FPS")
            HStack(spacing: 10) {
                Picker("", selection: $options.fps) {
                    ForEach([12, 15, 24, 30], id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
                .pickerStyle(.segmented)

                Stepper("", value: $options.fps, in: 1...60)
                    .labelsHidden()
                    .help("FPS personalizado")
            }

            rowLabel("Tamaño")
            Picker("", selection: $options.maxPixelSize) {
                Text("Auto (máx 480px)").tag(480)
                Text("Auto (máx 720px)").tag(720)
                Text("Auto (máx 1080px)").tag(1080)
            }
            .pickerStyle(.menu)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var optimizationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optimización")
                .font(.headline)

            Toggle("Dithering (recomendado)", isOn: $options.isDitheringEnabled)

            Toggle("Loop (infinito)", isOn: $options.isLoopEnabled)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Salida")
                .font(.headline)

            Text("Se guardará en: \(friendlyDirectoryName())")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Cambiar en Ajustes…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.link)

                Spacer()

                Button("Abrir carpeta") {
                    NSWorkspace.shared.open(outputDirectory)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var estimationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimación")
                .font(.headline)

            estimationRow(label: "Duración:", value: formatSeconds(selectionDurationSeconds))
            estimationRow(label: "Frames estimados:", value: "~\(estimatedFrames())")
            estimationRow(label: "Tamaño estimado:", value: "~\(formatBytes(estimatedSizeBytes()))")
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func estimationRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func friendlyDirectoryName() -> String {
        let path = outputDirectory.path
        if path.contains("/Downloads") || path.contains("/Descargas") {
            return "Descargas"
        }
        return outputDirectory.lastPathComponent
    }

    private func estimatedFrames() -> Int {
        let duration = max(0, selectionDurationSeconds)
        let fps = max(1, options.fps)
        return max(1, Int(ceil(duration * Double(fps))))
    }

    private func estimatedSizeBytes() -> Int64 {
        // Heuristic: roughly 0.05 bytes per pixel per frame for "medium" UI estimate.
        let frames = Double(estimatedFrames())
        let pixelsPerFrame = Double(options.maxPixelSize * options.maxPixelSize)
        let bytes = frames * pixelsPerFrame * 0.05
        return Int64(max(0, bytes))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0.0s" }
        return String(format: "%.1fs", max(0, seconds))
    }
}

#Preview {
    GifClipSidebarPreviewWrapper()
        .frame(height: 560)
}

private struct GifClipSidebarPreviewWrapper: View {
    @State private var options = GifExportOptions()

    var body: some View {
        GifClipSidebarView(
            options: $options,
            outputDirectory: URL(fileURLWithPath: "/Users/steven/Downloads"),
            selectionDurationSeconds: 4.2
        )
        .padding()
    }
}
