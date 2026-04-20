//
//  PermissionRequirementCard.swift
//  PeekOCR
//
//  Renders a polished card for one pending macOS permission.
//

import AppKit
import SwiftUI

/// Step card used inside the permissions requirements window.
struct PermissionRequirementCard: View {
    let permission: AppPermission
    let index: Int
    let isLast: Bool
    let onActivate: (AppPermission) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: permission.accentColor).opacity(0.14))
                        .frame(width: 28, height: 28)

                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(nsColor: permission.accentColor))
                }

                Rectangle()
                    .fill(Color(nsColor: permission.accentColor).opacity(0.10))
                    .frame(width: 1, height: 34)
                    .opacity(isLast ? 0 : 1)
            }

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: permission.accentColor).opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: permission.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(nsColor: permission.accentColor))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(permission.title)
                            .font(.body.weight(.semibold))

                        Text("Requerido")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(nsColor: permission.accentColor).opacity(0.12))
                            )
                            .foregroundStyle(Color(nsColor: permission.accentColor))
                    }

                    Text(permission.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(detailText, systemImage: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Activar") {
                    onActivate(permission)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color(nsColor: permission.accentColor))
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var detailText: String {
        switch permission {
        case .screenRecording:
            return "Necesario para OCR, capturas y clips GIF."
        case .accessibility:
            return "Necesario para que funcionen los atajos globales de PeekOCR."
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
            .overlay(
                LinearGradient(
                    colors: [
                        Color(nsColor: permission.accentColor).opacity(0.10),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(nsColor: permission.accentColor).opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}
