//
//  MenuBarActionButton.swift
//  PeekOCR
//
//  Button for quick actions in the menu bar popover.
//

import SwiftUI

/// Action button with icon, title, and shortcut display
struct MenuBarActionButton: View {
    let title: String
    let icon: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(.blue)
                    .symbolEffect(.bounce, options: .speed(1.4), value: isHovered)

                Text(title)
                    .font(.body)

                Spacer()

                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.blue.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(.horizontal, 6)
    }
}
