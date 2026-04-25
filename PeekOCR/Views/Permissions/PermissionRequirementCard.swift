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
    let isGranted: Bool
    let onActivate: (AppPermission) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(toneColor.opacity(0.14))
                        .frame(width: 28, height: 28)

                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(toneColor)
                }

                Rectangle()
                    .fill(toneColor.opacity(0.10))
                    .frame(width: 1, height: 34)
                    .opacity(isLast ? 0 : 1)
            }

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(toneColor.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: permission.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(toneColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(permission.title)
                            .font(.body.weight(.semibold))

                        Text(statusTitle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(toneColor.opacity(0.12))
                            )
                            .foregroundStyle(toneColor)
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

                Group {
                    if isGranted {
                        Label("Listo", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            onActivate(permission)
                        } label: {
                            Text("Activar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(activationButtonForeground)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minWidth: 74)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(toneColor)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: 84, alignment: .trailing)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var statusTitle: String {
        isGranted ? "Activo" : "Pendiente"
    }

    private var detailText: String {
        switch (permission, isGranted) {
        case (.screenRecording, true):
            return "PeekOCR ya puede usar la pantalla para OCR, capturas y clips."
        case (.accessibility, true):
            return "Los atajos globales de PeekOCR ya quedaron habilitados."
        case (.screenRecording, false):
            return "Necesario para OCR, capturas y clips GIF."
        case (.accessibility, false):
            return "Necesario para que funcionen los atajos globales de PeekOCR."
        }
    }

    private var toneColor: Color {
        isGranted ? .green : Color(nsColor: permission.accentColor)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.88 : 1))
            .overlay(
                LinearGradient(
                    colors: [
                        toneColor.opacity(colorScheme == .dark ? 0.14 : 0.07),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 12, y: 6)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? toneColor.opacity(0.20)
            : Color(nsColor: .separatorColor).opacity(0.18)
    }

    private var activationButtonForeground: Color {
        .black.opacity(0.82)
    }
}
