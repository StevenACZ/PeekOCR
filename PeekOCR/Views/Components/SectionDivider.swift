//
//  SectionDivider.swift
//  PeekOCR
//
//  Visual separator between settings sections.
//

import SwiftUI

/// Styled divider for separating sections
struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 20)
            .opacity(0.5)
    }
}
