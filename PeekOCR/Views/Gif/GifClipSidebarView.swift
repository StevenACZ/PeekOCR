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
            Text("clip_editor.export_section".localized)
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
        cardSection(title: "clip_editor.quality".localized) {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("clip_editor.profile".localized)
                Picker(
                    "",
                    selection: Binding(
                        get: { gifOptions.profile },
                        set: { newValue in gifOptions.applyProfilePreset(newValue) }
                    )
                ) {
                    ForEach(GifExportProfile.allCases) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                fieldLabel("FPS")
                Picker("", selection: $gifOptions.fps) {
                    ForEach(Constants.Gif.gifFpsOptions, id: \.self) { fps in
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
        cardSection(title: "clip_editor.quality".localized) {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("clip_editor.resolution".localized)
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

                fieldLabel("FPS")
                Picker("", selection: $videoOptions.fps) {
                    ForEach(Constants.Gif.videoFpsOptions, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help("clip_editor.fps_source_help".localized)
            }
        }
    }

    private var loopCard: some View {
        cardSection(title: "clip_editor.gif_options".localized) {
            Toggle("clip_editor.infinite_loop".localized, isOn: $gifOptions.isLoopEnabled)
                .toggleStyle(.switch)
                .help("clip_editor.infinite_loop_help".localized)
        }
    }

    private var outputCard: some View {
        cardSection(title: "clip_editor.output".localized) {
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
                        Label("common.open".localized, systemImage: "folder.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("clip_editor.change_in_settings".localized) {
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
        cardSection(title: "clip_editor.estimate".localized) {
            VStack(alignment: .leading, spacing: 8) {
                Text(estimateSummary())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let message = exportDisabledMessage {
                    InlineNoticeView(style: .warning, text: message)
                }

                estimationRow(label: "clip_editor.duration".localized, value: formatSeconds(selectionDurationSeconds))
                if exportFormat == .gif {
                    estimationRow(label: "clip_editor.frames".localized, value: "~\(estimatedGifFrames())")
                    estimationRow(label: "clip_editor.size".localized, value: "~\(formatBytes(estimatedGifSizeBytes()))")
                } else {
                    estimationRow(label: "clip_editor.size".localized, value: "~\(formatBytes(estimatedVideoSizeBytes()))")
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
}
