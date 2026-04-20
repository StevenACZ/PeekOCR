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
                            .foregroundStyle(.orange)
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
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)

                Text("Te guiaremos al ajuste correcto y verificaremos el estado cuando regreses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.14), lineWidth: 1)
                    )
            )
        }
    }

    private var titleText: String {
        switch missingCount {
        case 0, 1:
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
}
