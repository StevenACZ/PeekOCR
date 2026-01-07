//
//  StrokeWidthPicker.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI

/// A slider with visual preview for selecting stroke width - iOS style
struct StrokeWidthPicker: View {
    @Binding var strokeWidth: CGFloat

    /// Minimum stroke width
    private let minWidth: CGFloat = 1.0

    /// Maximum stroke width
    private let maxWidth: CGFloat = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with badge
            HStack {
                Text("GROSOR")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                // Value badge
                Text(String(format: "%.0f", strokeWidth))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
            }

            // Visual preview and slider
            HStack(spacing: 14) {
                // Visual preview circle
                StrokePreview(strokeWidth: strokeWidth, maxWidth: maxWidth)

                // Slider with custom style
                VStack(spacing: 6) {
                    Slider(value: $strokeWidth, in: minWidth...maxWidth, step: 1.0)
                        .tint(.accentColor)

                    // Min/Max labels
                    HStack {
                        Text("Fino")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Grueso")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Stroke Preview

private struct StrokePreview: View {
    let strokeWidth: CGFloat
    let maxWidth: CGFloat

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 44, height: 44)

            // Preview circle that scales with stroke width
            Circle()
                .fill(Color.primary)
                .frame(width: strokeWidth * 3, height: strokeWidth * 3)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: strokeWidth)
        }
    }
}

// MARK: - Preview

#Preview {
    StrokeWidthPicker(strokeWidth: .constant(3.0))
        .padding()
        .frame(width: 200)
        .background(.ultraThinMaterial)
}
