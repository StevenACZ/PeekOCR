//
//  HistoryItemRow.swift
//  PeekOCR
//
//  Row displaying a history item with copy action.
//

import SwiftUI

/// Row displaying a capture history item; clicking copies it back to the clipboard.
struct HistoryItemRow: View {
    let item: CaptureItem
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.captureType.displayColor.opacity(0.14))
                        .frame(width: 24, height: 24)

                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(item.captureType.displayColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayText)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(showCopied ? Color.green : Color.secondary)
                    .opacity(showCopied || isHovered ? 1 : 0)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(Theme.Anim.easeOut, value: isHovered)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
        .help("menu.history.copy_help".localized)
    }

    private func copy() {
        onTap()
        withAnimation(Theme.Anim.spring) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(Theme.Anim.easeOut) {
                showCopied = false
            }
        }
    }
}
