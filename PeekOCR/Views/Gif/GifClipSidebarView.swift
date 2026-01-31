//
//  GifClipSidebarView.swift
//  PeekOCR
//
//  Sidebar for configuring GIF export options and showing output/estimates.
//

import AppKit
import SwiftUI

/// Sidebar content for the clip editor (GIF/Video settings + estimates).
struct GifClipSidebarView: View {
    @Binding var exportFormat: ClipExportFormat
    @Binding var gifOptions: GifExportOptions
    @Binding var videoOptions: VideoExportOptions

    let outputDirectory: URL
    let selectionDurationSeconds: Double
    let sourceNominalFps: Double
    let exportDisabledMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            formatSection
            exportOptionsSection
            if exportFormat == .gif {
                loopSection
            }
            outputSection
            estimationSection
            Spacer()
        }
        .padding(16)
        .frame(width: 320)
        .background(Color.black.opacity(0.14))
    }

    private var header: some View {
        HStack {
            Text("Exportación")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            rowLabel("Formato")
            Picker("", selection: $exportFormat) {
                ForEach(ClipExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var exportOptionsSection: some View {
        switch exportFormat {
        case .gif:
            gifOptionsSection
        case .video:
            videoOptionsSection
        }
    }

    private var gifOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            rowLabel("Perfil")
            Picker("", selection: Binding(
                get: { gifOptions.profile },
                set: { newValue in gifOptions.applyProfilePreset(newValue) }
            )) {
                ForEach(GifExportProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)

            rowLabel("FPS")
            Picker("", selection: $gifOptions.fps) {
                ForEach([1, 15, 20], id: \.self) { fps in
                    Text("\(fps)").tag(fps)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var videoOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            rowLabel("Resolución")
            Picker("", selection: $videoOptions.resolution) {
                ForEach(VideoExportResolution.allCases) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
            .help(videoOptions.resolution.helpText)

            rowLabel("FPS")
            Text("30")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .help("Se exporta a 30 FPS (o menos si la fuente es menor).")

            if sourceNominalFps > 1, sourceNominalFps < 29 {
                InlineNoticeView(
                    style: .info,
                    text: "Este clip se grabó a ~\(Int(sourceNominalFps.rounded())) FPS. Se exportará a ~\(Int(min(30.0, sourceNominalFps).rounded())) FPS."
                )
            }

            rowLabel("Codec")
            Picker("", selection: $videoOptions.codec) {
                ForEach(VideoExportCodec.allCases) { codec in
                    Text(codec.displayName).tag(codec)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var loopSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exportFormat == .gif {
                Text("Opciones")
                    .font(.headline)

                Toggle("Loop (infinito)", isOn: $gifOptions.isLoopEnabled)
                    .help("Repite el GIF indefinidamente. Desactívalo para reproducir una sola vez.")
            }
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

            Text(estimateSummary())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let message = exportDisabledMessage {
                InlineNoticeView(style: .warning, text: message)
            }

            estimationRow(label: "Duración:", value: formatSeconds(selectionDurationSeconds))
            if exportFormat == .gif {
                estimationRow(label: "Frames:", value: "~\(estimatedGifFrames())")
                estimationRow(label: "Tamaño:", value: "~\(formatBytes(estimatedGifSizeBytes()))")
            } else {
                estimationRow(label: "Tamaño:", value: "~\(formatBytes(estimatedVideoSizeBytes()))")
            }
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

    private func estimatedGifFrames() -> Int {
        let duration = max(0, selectionDurationSeconds)
        let fps = max(1, gifOptions.fps)
        return max(1, Int(ceil(duration * Double(fps))))
    }

    private func estimatedGifSizeBytes() -> Int64 {
        // Heuristic: roughly 0.05 bytes per pixel per frame for UI estimate.
        let frames = Double(estimatedGifFrames())
        let pixelsPerFrame = Double(gifOptions.maxPixelSize * gifOptions.maxPixelSize)
        let bytes = frames * pixelsPerFrame * 0.05
        return Int64(max(0, bytes))
    }

    private func estimatedVideoSizeBytes() -> Int64 {
        let duration = max(0, selectionDurationSeconds)
        let size = videoOptions.resolution.maxSize
        let fps = max(1, videoOptions.fps)
        let bitsPerPixelPerFrame: Double = videoOptions.codec == .hevc ? 0.07 : 0.12
        let estimatedBitsPerSecond = Double(size.width * size.height) * Double(fps) * bitsPerPixelPerFrame
        let estimatedBytes = (estimatedBitsPerSecond / 8) * duration
        return Int64(max(0, estimatedBytes))
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

    private func estimateSummary() -> String {
        switch exportFormat {
        case .gif:
            return "GIF · \(gifOptions.profile.displayName) · \(gifOptions.fps) FPS"
        case .video:
            return "Video · \(videoOptions.resolution.displayName) · \(videoOptions.fps) FPS · \(videoOptions.codec.displayName)"
        }
    }
}
