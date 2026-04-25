//
//  PermissionRequirementsIntroView.swift
//  PeekOCR
//
//  Presents the introductory content for the permissions requirements window.
//

import SwiftUI

/// Introductory content that frames the pending permission setup.
struct PermissionRequirementsIntroView: View {
    let missingCount: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.22),
                                        Color.orange.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)

                        Image(systemName: "hand.raised.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(titleText)
                            .font(.title2.weight(.semibold))

                        Text("Faltan accesos del sistema para usar captura, OCR y atajos globales sin fricción.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                Text(summaryBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(minHeight: 122, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.88 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(headerBorderColor, lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Image(systemName: helperIconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)

                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.16 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12), lineWidth: 1)
                    )
            )
        }
    }

    private var accentColor: Color {
        missingCount == 0 ? .green : .orange
    }

    private var headerBorderColor: Color {
        colorScheme == .dark
            ? accentColor.opacity(0.20)
            : Color(nsColor: .separatorColor).opacity(0.16)
    }

    private var titleText: String {
        switch missingCount {
        case 0:
            return "Todo listo para capturar"
        case 1:
            return "Activa el permiso pendiente"
        default:
            return "Activa los permisos pendientes"
        }
    }

    private var summaryBadgeText: String {
        switch missingCount {
        case 0:
            return "Todo listo"
        case 1:
            return "1 pendiente"
        default:
            return "\(missingCount) pendientes"
        }
    }

    private var helperIconName: String {
        missingCount == 0 ? "checkmark.circle.fill" : "sparkles"
    }

    private var helperText: String {
        if missingCount == 0 {
            return "Ya puedes volver a PeekOCR y usar OCR, capturas y atajos globales con normalidad."
        }

        return "Te guiaremos al ajuste correcto y verificaremos el estado cuando regreses."
    }
}
