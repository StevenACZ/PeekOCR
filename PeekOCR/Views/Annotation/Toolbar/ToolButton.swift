//
//  ToolButton.swift
//  PeekOCR
//
//  Button for selecting an annotation tool with icon, label, and shortcut.
//

import SwiftUI

/// Button for selecting an annotation tool
struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Text(tool.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()

                ShortcutKeyBadge(key: tool.shortcutKey)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
    }
}
