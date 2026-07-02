//
//  EmptyStateView.swift
//  PeekOCR
//
//  Placeholder view when history is empty.
//

import SwiftUI

/// Empty state placeholder for lists.
struct EmptyStateView: View {
    let icon: String
    let message: String
    let detail: String?

    init(
        icon: String = "doc.text.magnifyingglass",
        message: String = "menu.history.empty".localized,
        detail: String? = nil
    ) {
        self.icon = icon
        self.message = message
        self.detail = detail
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
