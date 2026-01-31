//
//  InlineNoticeView.swift
//  PeekOCR
//
//  Small inline notice component for info/warning messages.
//

import SwiftUI

/// Visual style for inline notices.
enum InlineNoticeStyle {
    case info
    case warning
}

/// Compact callout used to explain constraints and states in the UI.
struct InlineNoticeView: View {
    let style: InlineNoticeStyle
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .padding(.top, 1)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(backgroundShape)
    }

    private var iconName: String {
        switch style {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch style {
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(accentColor.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
    }
}

