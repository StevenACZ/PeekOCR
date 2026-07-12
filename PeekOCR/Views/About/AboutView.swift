//
//  AboutView.swift
//  PeekOCR
//
//  Standalone about window content.
//

import SwiftUI

/// About window: app identity, version, feature chips, and links.
struct AboutView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var updateManager = UpdateManager.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var year: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        VStack(spacing: 18) {
            heroSection
            taglineSection
            featureChips
            separator
            linksSection
            footerSection
        }
        .padding(.horizontal, 26)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundLayer)
        // Identity reset so cached subtrees re-resolve strings on language change.
        .id(localization.language)
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 92, height: 92)
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 5)

            Text("PeekOCR")
                .font(.system(size: 24, weight: .bold))

            Text("about.version".localized(version, build))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            updateStatus
        }
    }

    /// Update capsule mirroring `UpdateManager.phase`, plus a manual
    /// "check for updates" affordance when nothing is pending.
    @ViewBuilder
    private var updateStatus: some View {
        switch updateManager.phase {
        case .idle:
            checkForUpdatesButton

        case .available(let version):
            VStack(spacing: 5) {
                Button {
                    updateManager.installPendingUpdate()
                } label: {
                    updateCapsule(
                        icon: "arrow.down.circle",
                        text: "about.update_install".localized(version)
                    )
                }
                .buttonStyle(.plain)

                if updateManager.releasePageURL != nil {
                    Button {
                        updateManager.openReleasePage()
                    } label: {
                        Text("about.update_release_notes".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }

        case .downloading(let fraction):
            updateProgressCapsule(
                text: "about.update_downloading".localized
                    + (fraction.map { " \(Int($0 * 100))%" } ?? ""))

        case .installing:
            updateProgressCapsule(text: "about.update_installing".localized)

        case .failed:
            Button {
                updateManager.installPendingUpdate()
            } label: {
                updateCapsule(
                    icon: "exclamationmark.arrow.circlepath",
                    text: "about.update_retry".localized
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var checkForUpdatesButton: some View {
        switch updateManager.manualCheckStatus {
        case .checking:
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
                Text("about.update_check".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                Text("about.update_up_to_date".localized)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Theme.accent)
        case .idle:
            Button {
                updateManager.checkForUpdatesManually()
            } label: {
                Text("about.update_check".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    private func updateCapsule(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)

            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
        .foregroundStyle(Theme.accent)
    }

    private func updateProgressCapsule(text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)

            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
        .foregroundStyle(Theme.accent)
    }

    private var taglineSection: some View {
        Text("about.tagline".localized)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var featureChips: some View {
        HStack(spacing: 8) {
            chip(icon: "doc.text.viewfinder", label: "OCR Vision")
            chip(icon: "qrcode", label: "about.chip.qr".localized)
            chip(icon: "film", label: "Clips")
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 1)
    }

    private var linksSection: some View {
        HStack(spacing: 10) {
            linkButton(icon: "link", label: "GitHub", url: "https://github.com/StevenACZ/PeekOCR")
            linkButton(
                icon: "ladybug",
                label: "about.link.report_issue".localized,
                url: "https://github.com/StevenACZ/PeekOCR/issues"
            )
        }
    }

    private var footerSection: some View {
        VStack(spacing: 3) {
            Text("about.footer.credit".localized)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("© \(year) StevenACZ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Builders

    private func chip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)

            Text(label)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.accent.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1))
        .foregroundStyle(Theme.accent)
    }

    private func linkButton(icon: String, label: String, url: String) -> some View {
        Button {
            if let target = URL(string: url) {
                NSWorkspace.shared.open(target)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
