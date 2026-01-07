//
//  TextInputOverlay.swift
//  PeekOCR
//
//  Floating text field for text annotation input with auto-focus.
//

import SwiftUI

/// Overlay text field for entering text annotations
struct TextInputOverlay: View {
    @Binding var text: String
    let position: CGPoint
    let color: Color
    let fontSize: CGFloat
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            TextField("Escribe aquí...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: max(14, fontSize), weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                .frame(minWidth: 180, maxWidth: 350)
                .fixedSize()
                .position(
                    x: min(max(position.x + 90, 120), geometry.size.width - 120),
                    y: min(max(position.y, 40), geometry.size.height - 40)
                )
                .focused($isFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
                .onSubmit {
                    onCommit()
                }
        }
    }
}
