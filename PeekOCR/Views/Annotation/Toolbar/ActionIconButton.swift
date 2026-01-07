//
//  ActionIconButton.swift
//  PeekOCR
//
//  Icon-only button for toolbar actions (undo, redo, clear).
//

import SwiftUI

/// Icon button with hover effects for toolbar actions
struct ActionIconButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovered && isEnabled ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .scaleEffect(isHovered && isEnabled ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("\(label) (\(shortcut))")
    }
}
