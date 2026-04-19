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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                qualityCard
                if exportFormat == .gif {
                    loopCard
                }
                outputCard
                estimationCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 320)
        .background(Color(NSColor.underPageBackgroundColor).opacity(0.6))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Exportación")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Picker("", selection: $exportFormat) {
                ForEach(ClipExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var qualityCard: some View {
        switch exportFormat {
        case .gif:
            gifQualityCard
        case .video:
            videoQualityCard
        }
    }

    private var gifQualityCard: some View {
        cardSection(title: "Calidad") {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Perfil")
                Picker("", selection: Binding(
                    get: { gifOptions.profile },
                    set: { newValue in gifOptions.applyProfilePreset(newValue) }
                )) {
                    ForEach(GifExportProfile.allCases) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                fieldLabel("FPS")
                Picker("", selection: $gifOptions.fps) {
                    ForEach([1, 15, 20], id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var videoQualityCard: some View {
        cardSection(title: "Calidad") {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Resolución")
                Picker("", selection: $videoOptions.resolution) {
                    ForEach(VideoExportResolution.allCases) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help(videoOptions.resolution.helpText)

                fieldLabel("Codec")
                Picker("", selection: $videoOptions.codec) {
                    ForEach(VideoExportCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Text("FPS")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("30 máximo")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .padding(.top, 2)
                .help("Se exporta a 30 FPS (o menos si la fuente es menor).")

                if sourceNominalFps > 1, sourceNominalFps < 29 {
                    InlineNoticeView(
                        style: .info,
                        text: "Este clip se grabó a ~\(Int(sourceNominalFps.rounded())) FPS. Se exportará a ~\(Int(min(30.0, sourceNominalFps).rounded())) FPS."
                    )
                }
            }
        }
    }

    private var loopCard: some View {
        cardSection(title: "Opciones GIF") {
            Toggle("Loop infinito", isOn: $gifOptions.isLoopEnabled)
                .toggleStyle(.switch)
                .help("Repite el GIF indefinidamente. Desactívalo para reproducir una sola vez.")
        }
    }

    private var outputCard: some View {
        cardSection(title: "Salida") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(friendlyDirectoryName())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        NSWorkspace.shared.open(outputDirectory)
                    } label: {
                        Label("Abrir", systemImage: "folder.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Cambiar en Ajustes…") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)

                    Spacer()
                }
            }
        }
    }

    private var estimationCard: some View {
        cardSection(title: "Estimación") {
            VStack(alignment: .leading, spacing: 8) {
                Text(estimateSummary())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let message = exportDisabledMessage {
                    InlineNoticeView(style: .warning, text: message)
                }

                estimationRow(label: "Duración", value: formatSeconds(selectionDurationSeconds))
                if exportFormat == .gif {
                    estimationRow(label: "Frames", value: "~\(estimatedGifFrames())")
                    estimationRow(label: "Tamaño", value: "~\(formatBytes(estimatedGifSizeBytes()))")
                } else {
                    estimationRow(label: "Tamaño", value: "~\(formatBytes(estimatedVideoSizeBytes()))")
                }
            }
        }
    }

    @ViewBuilder
    private func cardSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func estimationRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
    }

    private func friendlyDirectoryName() -> String {
        let path = outputDirectory.path
        if path.contains("/Downloads") || path.contains("/Descargas") {
            return "Descargas"
        }
        if path.contains("/Desktop") || path.contains("/Escritorio") {
            return "Escritorio"
        }
        return outputDirectory.lastPathComponent
    }

    private func estimatedGifFrames() -> Int {
        let duration = max(0, selectionDurationSeconds)
        let fps = max(1, gifOptions.fps)
        return max(1, Int(ceil(duration * Double(fps))))
    }

    private func estimatedGifSizeBytes() -> Int64 {
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
