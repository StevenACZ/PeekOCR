//
//  AnnotationDefaultsSection.swift
//  PeekOCR
//
//  Sliders for default annotation stroke width and font size.
//

import SwiftUI

/// Section for configuring default annotation settings
struct AnnotationDefaultsSection: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        Section {
            // Stroke Width Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Grosor de linea")
                    Spacer()
                    Text("\(Int(appSettings.defaultAnnotationStrokeWidth)) px")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                }

                Slider(value: $appSettings.defaultAnnotationStrokeWidth, in: 1...10, step: 1)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                HStack {
                    Text("1 px")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("5 px")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("10 px")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Font Size Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tamano de fuente")
                    Spacer()
                    Text("\(Int(appSettings.defaultAnnotationFontSize)) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                }

                Slider(value: $appSettings.defaultAnnotationFontSize, in: 12...48, step: 2)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                HStack {
                    Text("12 pt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("30 pt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("48 pt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("Anotaciones")
        } footer: {
            Text("Estos valores se usaran como predeterminados al abrir el editor de anotaciones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Form {
        AnnotationDefaultsSection(appSettings: AppSettings.shared)
    }
    .formStyle(.grouped)
}
