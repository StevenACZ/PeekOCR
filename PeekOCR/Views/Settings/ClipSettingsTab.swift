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
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    exportCard
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
            SettingsToggleRow(title: "Limitar duración", isOn: $settings.durationLimitEnabled)

            if settings.durationLimitEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Duración máxima")
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
                    ? "El clip se detiene automáticamente al llegar al límite. Mínimo \(Constants.Gif.maxDurationRange.lowerBound)s, máximo \(Constants.Gif.maxDurationRange.upperBound)s."
                    : "Sin límite: la grabación continúa hasta que la detengas con el botón Stop o el atajo."
            )
        }
        .animation(.smooth(duration: 0.25), value: settings.durationLimitEnabled)
    }

    private var recordingCard: some View {
        SettingsCard(icon: "record.circle", title: "Grabación") {
            segmentedRow(label: "FPS de grabación") {
                Picker("", selection: $settings.recordingFps) {
                    ForEach(Constants.Gif.recordingFpsOptions, id: \.self) { fps in
                        Text("\(fps)").tag(fps)
                    }
                }
            }

            SettingsToggleRow(title: "Mostrar el cursor", isOn: $settings.recordingShowsCursor)

            SettingsToggleRow(
                title: "Grabar audio del sistema",
                isOn: $settings.recordingCapturesSystemAudio
            )

            SettingsCaption(
                "Durante la selección, pulsa Espacio para grabar la pantalla completa. El audio del sistema se conserva al exportar MP4 (el GIF no lleva audio); macOS puede pedir el permiso de grabación de audio la primera vez."
            )
        }
    }

    private var exportCard: some View {
        SettingsCard(icon: "square.and.arrow.up", title: "Exportación") {
            segmentedRow(label: "Formato por defecto") {
                Picker("", selection: $settings.defaultExportFormat) {
                    ForEach(ClipExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            SettingsCaption("Define el formato que se preselecciona al abrir el editor.")
        }
    }

    private var gifCard: some View {
        SettingsCard(icon: "photo.stack", title: "GIF") {
            segmentedRow(label: "Perfil") {
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

            SettingsToggleRow(title: "Loop (infinito)", isOn: $settings.gifLoopEnabled)

            SettingsCaption("AI Debug es ideal para revisar frame-by-frame (ej: 10s → ~10 frames a 1 FPS).")
        }
    }

    private var videoCard: some View {
        SettingsCard(icon: "film", title: "Video (MP4)") {
            segmentedRow(label: "Resolución (máx)") {
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

            SettingsCaption("H.264 es más compatible. HEVC suele ser más ligero pero puede ser menos compatible.")
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
