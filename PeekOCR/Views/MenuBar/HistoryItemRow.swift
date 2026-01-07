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
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Clic para copiar")
    }
}
