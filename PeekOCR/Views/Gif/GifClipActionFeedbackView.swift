//
//  GifClipActionFeedbackView.swift
//  PeekOCR
//
//  Reusable status card used for clip editor progress and success feedback.
//

import SwiftUI

/// Tone used to style clip-editor action feedback.
enum GifClipActionFeedbackTone: Equatable {
    case progress
    case success
    case info
}

/// Presentation model for clip-editor feedback cards.
struct GifClipActionFeedback: Equatable {
    let tone: GifClipActionFeedbackTone
    let title: String
    let message: String
    let badgeText: String?
}

/// Shared feedback surface used by frame capture and export flows.
struct GifClipActionFeedbackView: View {
    enum LayoutStyle {
        case compact
        case prominent
    }

    let feedback: GifClipActionFeedback
    var layout: LayoutStyle = .compact

    var body: some View {
        switch layout {
        case .compact:
            compactBody
        case .prominent:
            prominentBody
        }
    }

    private var compactBody: some View {
        HStack(alignment: .center, spacing: 8) {
            compactIndicator

            Text(feedback.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(feedback.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(-1)

            if let badgeText = feedback.badgeText {
                Text(badgeText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var prominentBody: some View {
        HStack(alignment: .center, spacing: contentSpacing) {
            leadingIndicator

            VStack(alignment: .leading, spacing: textSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(feedback.title)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let badgeText = feedback.badgeText {
                        badge(text: badgeText)
                    }
                }

                Text(feedback.message)
                    .font(messageFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var compactIndicator: some View {
        switch feedback.tone {
        case .progress:
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        case .info:
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        switch feedback.tone {
        case .progress:
            ProgressView()
                .controlSize(layout == .prominent ? .large : .regular)
                .tint(accentColor)
                .frame(width: indicatorSize, height: indicatorSize)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: indicatorFontSize, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: indicatorSize, height: indicatorSize)
        case .info:
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: indicatorFontSize, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: indicatorSize, height: indicatorSize)
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accentColor.opacity(0.12), in: Capsule(style: .continuous))
    }

    private var accentColor: Color {
        switch feedback.tone {
        case .progress:
            return .blue
        case .success:
            return .green
        case .info:
            return .teal
        }
    }

    private var backgroundMaterial: AnyShapeStyle {
        switch layout {
        case .compact:
            return AnyShapeStyle(.regularMaterial)
        case .prominent:
            return AnyShapeStyle(.ultraThickMaterial)
        }
    }

    private var cornerRadius: CGFloat {
        switch layout {
        case .compact:
            return 14
        case .prominent:
            return 18
        }
    }

    private var contentSpacing: CGFloat {
        switch layout {
        case .compact:
            return 10
        case .prominent:
            return 14
        }
    }

    private var textSpacing: CGFloat {
        switch layout {
        case .compact:
            return 4
        case .prominent:
            return 6
        }
    }

    private var horizontalPadding: CGFloat {
        switch layout {
        case .compact:
            return 14
        case .prominent:
            return 18
        }
    }

    private var verticalPadding: CGFloat {
        switch layout {
        case .compact:
            return 12
        case .prominent:
            return 16
        }
    }

    private var indicatorSize: CGFloat {
        switch layout {
        case .compact:
            return 24
        case .prominent:
            return 32
        }
    }

    private var indicatorFontSize: CGFloat {
        switch layout {
        case .compact:
            return 18
        case .prominent:
            return 24
        }
    }

    private var titleFont: Font {
        switch layout {
        case .compact:
            return .subheadline.weight(.semibold)
        case .prominent:
            return .headline
        }
    }

    private var messageFont: Font {
        switch layout {
        case .compact:
            return .caption
        case .prominent:
            return .subheadline
        }
    }
}

#Preview("Compact") {
    VStack(spacing: 12) {
        GifClipActionFeedbackView(
            feedback: GifClipActionFeedback(
                tone: .progress,
                title: "Guardando frame…",
                message: "Se guardará como PNG en Descargas.",
                badgeText: "PNG"
            )
        )

        GifClipActionFeedbackView(
            feedback: GifClipActionFeedback(
                tone: .success,
                title: "Frame guardado",
                message: "PeekOCR_Frame_2026-04-18_19-48-22.png",
                badgeText: "PNG"
            )
        )
    }
    .padding()
    .frame(width: 360)
}

#Preview("Prominent") {
    GifClipActionFeedbackView(
        feedback: GifClipActionFeedback(
            tone: .progress,
            title: "Exportando GIF…",
            message: "Guardando en Descargas. Esto puede tardar unos segundos.",
            badgeText: "GIF"
        ),
        layout: .prominent
    )
    .padding()
    .frame(width: 360, height: 220)
    .background(Color.black.opacity(0.2))
}
