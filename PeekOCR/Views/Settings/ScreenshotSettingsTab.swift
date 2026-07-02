//
//  ScreenshotSettingsTab.swift
//  PeekOCR
//
//  Settings tab for screenshot capture, saving, and annotation defaults.
//

import AppKit
import SwiftUI

/// Screenshot settings tab.
struct ScreenshotSettingsTab: View {
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var appSettings = AppSettings.shared

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    saveCard
                    imageCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                annotationsCard
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .padding(16)
        }
    }

    // MARK: - Cards

    private var saveCard: some View {
        SettingsCard(icon: "square.and.arrow.down", title: "settings.captures.saving".localized) {
            SettingsToggleRow(title: "settings.captures.copy_to_clipboard".localized, isOn: $settings.copyToClipboard)

            SettingsToggleRow(title: "settings.captures.save_to_file".localized, isOn: $settings.saveToFile)

            SettingsCaption("settings.captures.save_both_caption".localized)

            if settings.saveToFile {
                Divider()

                locationRows
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.25), value: settings.saveToFile)
        .animation(.smooth(duration: 0.25), value: settings.saveLocation)
    }

    private var locationRows: some View {
        Group {
            HStack {
                Text("settings.captures.destination_folder".localized)
                    .font(.system(size: 13))

                Spacer()

                Picker("", selection: $settings.saveLocation) {
                    ForEach(SaveLocation.allCases) { location in
                        // Interpolated image + spaces: Label renders the icon glued
                        // to the title in the collapsed menu picker.
                        Text("\(Image(systemName: location.icon))  \(location.displayName)")
                            .tag(location)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            if settings.saveLocation == .custom {
                HStack {
                    Text(settings.customSavePath.isEmpty ? "settings.captures.no_folder_selected".localized : settings.customSavePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("settings.captures.choose".localized) {
                        chooseSaveFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var imageCard: some View {
        SettingsCard(icon: "photo", title: "settings.captures.image".localized) {
            HStack {
                Text("settings.captures.format".localized)
                    .font(.system(size: 13))

                Spacer()

                Picker("", selection: $settings.imageFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        Text("\(format.displayName) (\(format.description))").tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            if settings.imageFormat == .jpg {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("settings.captures.jpg_quality".localized)
                            .font(.system(size: 13))

                        Spacer()

                        Text("\(Int(settings.imageQuality * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }

                    Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.1)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("settings.captures.image_size".localized)
                        .font(.system(size: 13))

                    Spacer()

                    Text("\(Int(settings.imageScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }

                Slider(value: $settings.imageScale, in: 0.1...1.0, step: 0.1)
                    .labelsHidden()
                    .tint(Theme.accent)

                HStack {
                    Text("10%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("100%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            SettingsCaption(
                settings.imageScale < 1.0
                    ? "settings.captures.scale_caption_reduced".localized(Int(settings.imageScale * 100))
                    : "settings.captures.scale_caption_full".localized
            )
        }
        .animation(.smooth(duration: 0.25), value: settings.imageFormat)
    }

    private var annotationsCard: some View {
        SettingsCard(icon: "pencil.and.scribble", title: "settings.captures.annotations".localized) {
            annotationSlider(
                label: "settings.captures.stroke_width".localized,
                value: $appSettings.defaultAnnotationStrokeWidth,
                range: 1...10,
                step: 1,
                unit: "px"
            )

            annotationSlider(
                label: "settings.captures.pen_width".localized,
                value: $appSettings.defaultPenStrokeWidth,
                range: 1...12,
                step: 1,
                unit: "px"
            )

            annotationSlider(
                label: "settings.captures.font_size".localized,
                value: $appSettings.defaultAnnotationFontSize,
                range: 12...48,
                step: 2,
                unit: "pt"
            )

            SettingsCaption("settings.captures.annotations_caption".localized)
        }
    }

    private func annotationSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13))

                Spacer()

                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }

            Slider(value: value, in: range, step: step)
                .labelsHidden()
                .tint(Theme.accent)

            HStack {
                Text("\(Int(range.lowerBound)) \(unit)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(Int(range.upperBound)) \(unit)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "settings.captures.select".localized
        panel.message = "settings.captures.choose_folder_message".localized

        if panel.runModal() == .OK, let url = panel.url {
            settings.customSavePath = url.path
        }
    }
}

// MARK: - Preview

#Preview {
    ScreenshotSettingsTab()
}
