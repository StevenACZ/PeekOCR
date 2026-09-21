import SwiftUI

struct CapturePreviewView: View {
    @ObservedObject var controller: CapturePreviewController
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            header
            if controller.assets.count == 1, let asset = controller.assets.first {
                thumbnail(asset, height: 178)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(controller.assets) { asset in
                            thumbnail(asset, height: 96)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            footer
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, x: 2, y: 3)
        }
        .padding(10)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: controller.assets.map(\.id))
        .id(localization.language)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: controller.assets.count > 1 ? "square.stack.3d.up.fill" : "photo.fill")
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
            Text(controller.assets.count == 1 ? "preview.capture".localized : "preview.captures".localized(controller.assets.count))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: controller.dismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("preview.hide".localized)
            .accessibilityLabel("preview.hide".localized)
        }
    }

    private func thumbnail(_ asset: CaptureClipboardAsset, height: CGFloat) -> some View {
        Image(decorative: asset.thumbnail, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button {
                    controller.remove(asset.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 23, height: 23)
                        .background(.black.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("preview.remove".localized)
                .accessibilityLabel("preview.remove_number".localized((controller.assets.firstIndex { $0.id == asset.id } ?? 0) + 1))
            }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: controller.copied ? "checkmark.circle.fill" : "photo.on.rectangle")
                    .foregroundStyle(controller.copied ? .green : .secondary)
                Text(footerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button(action: controller.copy) {
                    Text(controller.copied ? "⌘V" : "preview.copy".localized)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("preview.copy".localized)
                .accessibilityLabel("preview.copy".localized)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            GeometryReader { geometry in
                Capsule().fill(Theme.accent.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.65))
                            .frame(width: geometry.size.width * controller.countdown)
                            .animation(reduceMotion ? nil : .linear(duration: controller.countdownDuration), value: controller.countdown)
                    }
            }
            .frame(height: 2)
        }
    }

    private var footerText: String {
        guard controller.copied else { return "preview.ready".localized }
        if controller.assets.count > 1 {
            return settings.groupedCopy ? "preview.group_copied".localized : "preview.latest_copied".localized
        }
        return "preview.copied".localized
    }
}
