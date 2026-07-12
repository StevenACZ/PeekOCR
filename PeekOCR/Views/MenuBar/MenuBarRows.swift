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

/// Update lifecycle row: pending update → one-click install with inline
/// download/install progress; a failed install offers a retry.
struct UpdateMenuRow: View {
    @ObservedObject var manager: UpdateManager

    var body: some View {
        switch manager.phase {
        case .idle:
            EmptyView()

        case .available(let version):
            ActionRow(
                icon: "arrow.down.circle",
                title: "menu.update_available".localized,
                subtitle: "menu.update_install_hint".localized(version)
            ) {
                manager.installPendingUpdate()
            }

        case .downloading(let fraction):
            UpdateProgressRow(
                title: "menu.update_downloading".localized,
                subtitle: fraction.map { "\(Int($0 * 100))%" },
                fraction: fraction
            )

        case .installing:
            UpdateProgressRow(
                title: "menu.update_installing".localized,
                subtitle: "menu.update_relaunch".localized,
                fraction: nil
            )

        case .failed:
            ActionRow(
                icon: "exclamationmark.arrow.circlepath",
                title: "menu.update_failed".localized,
                subtitle: "menu.update_retry_hint".localized
            ) {
                manager.installPendingUpdate()
            }
        }
    }
}

/// Non-interactive progress row shown while an update downloads or installs.
struct UpdateProgressRow: View {
    let title: String
    let subtitle: String?
    let fraction: Double?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let fraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.circular)
                } else {
                    ProgressView()
                }
            }
            .controlSize(.small)
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
