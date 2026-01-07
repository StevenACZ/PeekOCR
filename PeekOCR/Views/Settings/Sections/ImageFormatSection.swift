//
//  ImageFormatSection.swift
//  PeekOCR
//
//  Picker for image format with quality slider for JPG.
//

import SwiftUI

/// Section for selecting image format and quality
struct ImageFormatSection: View {
    @ObservedObject var settings: ScreenshotSettings

    var body: some View {
        Section {
            Picker("Formato", selection: $settings.imageFormat) {
                ForEach(ImageFormat.allCases) { format in
                    HStack {
                        Text(format.displayName)
                        Text("(\(format.description))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(format)
                }
            }

            if settings.imageFormat == .jpg {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Calidad JPG")
                        Spacer()
                        Text("\(Int(settings.imageQuality * 100))%")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.1)
                }
            }
        } header: {
            Text("Formato de Imagen")
        }
    }
}

#Preview {
    Form {
        ImageFormatSection(settings: ScreenshotSettings.shared)
    }
    .formStyle(.grouped)
}
