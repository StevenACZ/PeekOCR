//
//  HistoryItemRow.swift
//  PeekOCR
//
//  Row displaying a history item with copy action.
//

import SwiftUI

/// Row displaying a capture history item
struct HistoryItemRow: View {
    let item: CaptureItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.caption)
                    .foregroundStyle(item.captureType.displayColor)
                    .frame(width: 16)

                Text(item.displayText)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text(item.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
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
        .help("Clic para copiar")
    }
}
