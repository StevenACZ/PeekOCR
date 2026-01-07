//
//  ImageScaleSection.swift
//  PeekOCR
//
//  Slider for adjusting output image scale percentage.
//

import SwiftUI

/// Section for adjusting image scale/size
struct ImageScaleSection: View {
    @ObservedObject var settings: ScreenshotSettings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tamano de imagen")
                    Spacer()
                    Text("\(Int(settings.imageScale * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                }

                Slider(value: $settings.imageScale, in: 0.1...1.0, step: 0.1)

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
        } header: {
            Text("Tamano de Imagen")
        } footer: {
            if settings.imageScale < 1.0 {
                Text("La imagen se reducira al \(Int(settings.imageScale * 100))% de su tamano original.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("La imagen se guardara a tamano completo (maxima calidad).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Form {
        ImageScaleSection(settings: ScreenshotSettings.shared)
    }
    .formStyle(.grouped)
}
