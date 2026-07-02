//
//  ClipSettingsTab.swift
//  PeekOCR
//
//  Settings tab for clip capture and export defaults (GIF/Video).
//

import SwiftUI

/// Clip capture/export settings tab.
struct ClipSettingsTab: View {
    @ObservedObject private var settings = GifClipSettings.shared

    private var durationRange: ClosedRange<Double> {
        let range = Constants.Gif.maxDurationRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    durationCard
                    recordingCard
                    exportCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    gifCard
                    videoCard
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .padding(16)
        }
    }

    // MARK: - Cards

    private var durationCard: some View {
        SettingsCard(icon: "timer", title: "Clip") {
            SettingsToggleRow(title: "settings.clips.limit_duration".localized, isOn: $settings.durationLimitEnabled)

            if settings.durationLimitEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("settings.clips.max_duration".localized)
                            .font(.system(size: 13))

                        Spacer()

                        Text("\(settings.maxDurationSeconds)s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(settings.maxDurationSeconds) },
                            set: { settings.maxDurationSeconds = Int($0.rounded()) }
                        ),
                        in: durationRange,
                        step: 1
                    )
                    .labelsHidden()
                    .tint(Theme.accent)

                    HStack {
                        Text("\(Constants.Gif.maxDurationRange.lowerBound)s")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        Text("\(Constants.Gif.maxDurationRange.upperBound)s")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SettingsCaption(
                settings.durationLimitEnabled
                    ? "settings.clips.duration_caption_limited".localized(
                        Constants.Gif.maxDurationRange.lowerBound,
                        Constants.Gif.maxDurationRange.upperBound
                    )
                    : "settings.clips.duration_caption_unlimited".localized
            )
        }
        .animation(.smooth(duration: 0.25), value: settings.durationLimitEnabled)
    }

    private var recordingCard: some View {
        SettingsCard(icon: "record.circle", title: "settings.clips.recording".localized) {
            segmentedRow(label: "settings.clips.recording_fps".localized) {
                Picker("", selection: $settings.recordingFps) {
                    ForEach(Constants.Gif.recordingFpsOptions, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
            }

            SettingsToggleRow(title: "settings.clips.show_cursor".localized, isOn: $settings.recordingShowsCursor)

            SettingsToggleRow(
                title: "settings.clips.system_audio".localized,
                isOn: $settings.recordingCapturesSystemAudio
            )

            SettingsCaption(
                "settings.clips.recording_caption".localized
            )
        }
    }

    private var exportCard: some View {
        SettingsCard(icon: "square.and.arrow.up", title: "settings.clips.export".localized) {
            segmentedRow(label: "settings.clips.default_format".localized) {
                Picker("", selection: $settings.defaultExportFormat) {
                    ForEach(ClipExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            SettingsCaption("settings.clips.default_format_caption".localized)
        }
    }

    private var gifCard: some View {
        SettingsCard(icon: "photo.stack", title: "GIF") {
            segmentedRow(label: "settings.clips.profile".localized) {
                Picker("", selection: $settings.gifProfile) {
                    ForEach(GifExportProfile.allCases) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
            }

            segmentedRow(label: "FPS") {
                Picker("", selection: $settings.gifFps) {
                    ForEach(Constants.Gif.gifFpsOptions, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
            }

            SettingsToggleRow(title: "settings.clips.loop".localized, isOn: $settings.gifLoopEnabled)

            SettingsCaption("settings.clips.gif_caption".localized)
        }
    }

    private var videoCard: some View {
        SettingsCard(icon: "film", title: "Video (MP4)") {
            segmentedRow(label: "settings.clips.max_resolution".localized) {
                Picker("", selection: $settings.videoResolution) {
                    ForEach(VideoExportResolution.allCases) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
                .help(settings.videoResolution.helpText)
            }

            segmentedRow(label: "FPS") {
                Picker("", selection: $settings.videoFps) {
                    ForEach(Constants.Gif.videoFpsOptions, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
            }

            segmentedRow(label: "Codec") {
                Picker("", selection: $settings.videoCodec) {
                    ForEach(VideoExportCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
            }

            SettingsCaption("settings.clips.codec_caption".localized)
        }
    }

    // MARK: - Builders

    private func segmentedRow(
        label: String,
        @ViewBuilder picker: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13))

            picker()
                .labelsHidden()
                .pickerStyle(.segmented)
        }
    }
}

// MARK: - Preview

#Preview {
    ClipSettingsTab()
}
