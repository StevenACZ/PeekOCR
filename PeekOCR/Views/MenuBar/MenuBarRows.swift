//
//  MenuBarRows.swift
//  PeekOCR
//
//  Reusable rows and badges for the menu bar panel.
//

import SwiftUI

/// Hover-filled action row with icon, optional subtitle, and trailing chevron.
struct ActionRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var isDestructive = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? Color.red : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(isDestructive ? Color.red : Color.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Update card shown under the popover header while an update is pending.
struct UpdateCard: View {
    @ObservedObject var manager: UpdateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: manager.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch manager.phase {
        case .idle:
            EmptyView()

        case .available(let version):
            headline(
                icon: "arrow.down.circle.fill",
                title: "update.card.available_title".localized(version),
                subtitle: "update.card.available_subtitle".localized
            )

            cardButton(title: "update.card.update".localized) {
                manager.installPendingUpdate()
            }

        case .downloading(let fraction):
            headline(
                icon: "arrow.down.circle",
                title: versionText.isEmpty
                    ? "update.card.downloading_short".localized
                    : "update.card.downloading_title".localized(versionText),
                subtitle: nil
            )

            HStack(spacing: 8) {
                Group {
                    if let fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView()
                    }
                }
                .progressViewStyle(.linear)
                .tint(Theme.accent)

                if let fraction {
                    Text("\(Int(fraction * 100)) %")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

        case .readyToInstall(let version):
            headline(
                icon: "checkmark.circle.fill",
                title: version.isEmpty
                    ? "update.card.ready_short".localized
                    : "update.card.ready_title".localized(version),
                subtitle: "update.card.ready_subtitle".localized
            )

            HStack(spacing: 8) {
                cardButton(title: "update.card.install_now".localized) {
                    manager.installNow()
                }

                Button {
                    manager.installLater()
                } label: {
                    Text("update.card.later".localized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

        case .installing:
            headline(
                icon: "arrow.triangle.2.circlepath",
                title: versionText.isEmpty
                    ? "update.card.installing_short".localized
                    : "update.card.installing_title".localized(versionText),
                subtitle: "update.card.installing_subtitle".localized
            )

            ProgressView()
                .progressViewStyle(.linear)
                .tint(Theme.accent)

        case .failed:
            headline(
                icon: "exclamationmark.arrow.circlepath",
                title: "update.card.failed_title".localized,
                subtitle: "update.card.failed_subtitle".localized
            )

            cardButton(title: "update.card.retry".localized) {
                manager.installNow()
            }
        }
    }

    private var versionText: String {
        switch manager.phase {
        case .available(let version), .readyToInstall(let version), .failed(let version):
            return version
        case .idle, .downloading, .installing:
            return manager.pendingVersion ?? ""
        }
    }

    private func headline(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func cardButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .controlSize(.small)
    }
}

/// Small pill showing a keyboard shortcut.
struct HotkeyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }
}
