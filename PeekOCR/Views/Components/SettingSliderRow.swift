//
//  SettingSliderRow.swift
//  PeekOCR
//
//  Reusable slider row with label, value display, and indicators.
//

import SwiftUI

/// Reusable slider component for settings views
struct SettingSliderRow: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayFormatter: (Double) -> String
    let indicators: [String]?

    init(
        title: String,
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        displayFormatter: @escaping (Double) -> String = { "\(Int($0))" },
        indicators: [String]? = nil
    ) {
        self.title = title
        self.icon = icon
        self._value = value
        self.range = range
        self.step = step
        self.displayFormatter = displayFormatter
        self.indicators = indicators
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title and value
            HStack {
                Label(title, systemImage: icon)

                Spacer()

                Text(displayFormatter(value))
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Slider
            Slider(value: $value, in: range, step: step)

            // Indicators
            if let indicators = indicators {
                HStack {
                    ForEach(Array(indicators.enumerated()), id: \.offset) { index, text in
                        if index > 0 { Spacer() }
                        Text(text)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        SettingSliderRow(
            title: "Escala",
            icon: "arrow.up.left.and.arrow.down.right",
            value: .constant(50),
            range: 10...100,
            step: 10,
            displayFormatter: { "\(Int($0))%" },
            indicators: ["10%", "50%", "100%"]
        )
    }
    .padding()
}
