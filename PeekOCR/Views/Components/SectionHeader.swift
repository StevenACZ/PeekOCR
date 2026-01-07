//
//  SectionHeader.swift
//  PeekOCR
//
//  Section title component with uppercase styling.
//

import SwiftUI

/// Header for settings/toolbar sections
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
