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

    var body: some View {
        Form {
            durationSection
            defaultsSection
            gifDefaultsSection
            videoDefaultsSection
        }
        .formStyle(.grouped)
        .padding()
    }

    private var durationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duración máxima")
                    Spacer()
                    Text("\(settings.maxDurationSeconds)s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.maxDurationSeconds) },
                        set: { settings.maxDurationSeconds = Int($0.rounded()) }
                    ),
                    in: Double(Constants.Gif.maxDurationRange.lowerBound)...Double(Constants.Gif.maxDurationRange.upperBound),
                    step: 1
                )
                .labelsHidden()
                .frame(maxWidth: .infinity)

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
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("Clip")
        } footer: {
            Text("El clip se detiene automáticamente al llegar al límite. Mínimo \(Constants.Gif.maxDurationRange.lowerBound)s, máximo \(Constants.Gif.maxDurationRange.upperBound)s.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var defaultsSection: some View {
        Section {
            Picker("Formato por defecto", selection: $settings.defaultExportFormat) {
                ForEach(ClipExportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Exportación")
        } footer: {
            Text("Define el formato que se preselecciona al abrir el editor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gifDefaultsSection: some View {
        Section {
            Picker("Perfil", selection: $settings.gifProfile) {
                ForEach(GifExportProfile.allCases) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)

            Picker("FPS", selection: $settings.gifFps) {
                Text("1").tag(1)
                Text("15").tag(15)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)

            Toggle("Loop (infinito)", isOn: $settings.gifLoopEnabled)
        } header: {
            Text("GIF")
        } footer: {
            Text("AI Debug es ideal para revisar frame-by-frame (ej: 10s → ~10 frames a 1 FPS).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var videoDefaultsSection: some View {
        Section {
            Picker("Resolución (máx)", selection: $settings.videoResolution) {
                ForEach(VideoExportResolution.allCases) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }
            .pickerStyle(.segmented)
            .help(settings.videoResolution.helpText)

            HStack {
                Text("FPS")
                Spacer()
                Text("30")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Picker("Codec", selection: $settings.videoCodec) {
                ForEach(VideoExportCodec.allCases) { codec in
                    Text(codec.displayName).tag(codec)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Video (MP4 sin audio)")
        } footer: {
            Text("H.264 es más compatible. HEVC suele ser más ligero pero puede ser menos compatible.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ClipSettingsTab()
}
