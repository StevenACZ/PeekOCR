//
//  EmptyStateView.swift
//  PeekOCR
//
//  Placeholder view when history is empty.
//

import SwiftUI

/// Empty state placeholder for lists
struct EmptyStateView: View {
    let icon: String
    let message: String

    init(icon: String = "doc.text.magnifyingglass", message: String = "No hay capturas recientes") {
        self.icon = icon
        self.message = message
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
