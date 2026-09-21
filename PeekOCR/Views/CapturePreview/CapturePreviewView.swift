import SwiftUI

struct CapturePreviewView: View {
    @ObservedObject var controller: CapturePreviewController
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingOlder = false

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CapturePreviewLayout.spacing) {
                        ForEach(controller.assets.reversed()) { asset in
                            thumbnail(asset)
                                .id(asset.id)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.never)
                .scrollDisabled(controller.assets.count <= CapturePreviewLayout.visibleLimit)
                .frame(height: controller.previewViewportHeight)

                if controller.assets.count > CapturePreviewLayout.visibleLimit {
                    Button {
                        showingOlder.toggle()
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                            if showingOlder, let id = controller.assets.first?.id {
                                proxy.scrollTo(id, anchor: .bottom)
                            } else if let id = controller.assets.last?.id {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    } label: {
                        Label(
                            showingOlder
                                ? "preview.latest".localized
                                : "preview.older".localized(controller.assets.count - CapturePreviewLayout.visibleLimit),
                            systemImage: showingOlder ? "chevron.up" : "chevron.down"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                }

                footer
                    .frame(height: 32)
                    .padding(.horizontal, 12)
            }
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: controller.assets.last?.id) { _, id in
                showingOlder = false
                if let id { proxy.scrollTo(id, anchor: .top) }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.26), value: controller.assets.map(\.id))
        .id(localization.language)
    }

    private func thumbnail(_ asset: CaptureClipboardAsset) -> some View {
        let size = controller.previewLayout.cardSize(for: CGSize(width: asset.thumbnail.width, height: asset.thumbnail.height))
        return Image(decorative: asset.thumbnail, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width - 8, height: size.height - 8)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 2)
            .overlay(alignment: .bottomLeading) {
                if controller.assets.count > 1 {
                    Text("\((controller.assets.firstIndex { $0.id == asset.id } ?? 0) + 1)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    controller.remove(asset.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(9)
                .opacity(controller.isHovered ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: controller.isHovered)
                .help("preview.remove".localized)
                .accessibilityLabel("preview.remove_number".localized((controller.assets.firstIndex { $0.id == asset.id } ?? 0) + 1))
            }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: controller.assets.count > 1 ? "square.stack" : "photo")
                    .font(.system(size: 11, weight: .medium))
                Text(controller.assets.count == 1 ? "preview.capture".localized : "preview.captures".localized(controller.assets.count))
                    .font(.system(size: 11, weight: .medium))
                if !settings.groupedCopy && controller.assets.count > 1 {
                    Text("preview.latest_only".localized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Button(action: controller.copy) {
                    Text(controller.copied ? "⌘V" : "preview.copy".localized)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("preview.copy".localized)
                .accessibilityLabel("preview.copy".localized)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Button(action: controller.dismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().trim(from: 0, to: controller.countdown)
                            .stroke(.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .linear(duration: controller.countdownDuration), value: controller.countdown)
                    }
            }
            .buttonStyle(.plain)
            .help("preview.hide".localized)
            .accessibilityLabel("preview.hide".localized)
        }
        .foregroundStyle(.primary)
    }
}
