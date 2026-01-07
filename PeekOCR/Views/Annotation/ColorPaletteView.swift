//
//  ColorPaletteView.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI

/// A grid of color circles for selecting annotation color - iOS style
struct ColorPaletteView: View {
    @Binding var selectedColor: Color

    /// Available colors for annotation
    private let colors: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple,
        .black,
        .white
    ]

    /// Number of columns in the grid
    private let columns = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("COLOR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    ColorCircle(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Color Circle

private struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring for selection
                if isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2.5)
                        .frame(width: 38, height: 38)
                }

                // White ring background for selected
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 34, height: 34)
                }

                // Main color circle
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .shadow(color: color.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 5 : 3, y: 2)
                    .overlay(
                        Circle()
                            .stroke(color == .white ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                    )

                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(contrastColor)
                }
            }
            .frame(width: 40, height: 40)
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(colorName)
    }

    /// Get contrasting color for checkmark visibility
    private var contrastColor: Color {
        switch color {
        case .white, .yellow:
            return .black
        default:
            return .white
        }
    }

    /// Display name for the color
    private var colorName: String {
        switch color {
        case .red: return "Rojo"
        case .orange: return "Naranja"
        case .yellow: return "Amarillo"
        case .green: return "Verde"
        case .blue: return "Azul"
        case .purple: return "Morado"
        case .black: return "Negro"
        case .white: return "Blanco"
        default: return "Color"
        }
    }
}

// MARK: - Preview

#Preview {
    ColorPaletteView(selectedColor: .constant(.red))
        .padding()
        .frame(width: 200)
        .background(.ultraThinMaterial)
}
