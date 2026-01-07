//
//  ShortcutKeyBadge.swift
//  PeekOCR
//
//  Small badge displaying a keyboard shortcut key.
//

import SwiftUI

/// Badge showing a keyboard shortcut key
struct ShortcutKeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
    }
}
