import AppKit
import SwiftUI

final class PermissionOverlayWindowController: NSWindowController {
    private let hostApp: PermissionHostApp
    private let permission: AppPermission
    private let onClose: () -> Void
    private var isGranted = false
    private var measuredSize: CGSize?
    private var hostingController: NSHostingController<AnyView>?

    init(hostApp: PermissionHostApp, permission: AppPermission, onClose: @escaping () -> Void) {
        self.hostApp = hostApp
        self.permission = permission
        self.onClose = onClose
        let panel = PassiveOverlayPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        super.init(window: panel)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.animationBehavior = .none
        updateContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setGranted(_ granted: Bool) {
        guard granted != isGranted else { return }
        isGranted = granted
        updateContent()
    }

    private func updateContent() {
        guard let window else { return }
        window.contentViewController = nil
        hostingController = nil
        measuredSize = nil
        if isGranted {
            let view = PermissionGrantedGuideView(permission: permission, width: 400, onClose: onClose)
            let hosting = NSHostingController(rootView: AnyView(view))
            hosting.sizingOptions = []
            hosting.safeAreaRegions = []
            hostingController = hosting
            window.contentViewController = hosting
        } else {
            let content = PermissionOverlayContentView(hostApp: hostApp, permission: permission, onClose: onClose)
            window.contentView = content
        }
    }

    func present(from sourceFrameInScreen: CGRect?, settingsFrame: CGRect, visibleFrame: CGRect) {
        updatePosition(with: settingsFrame, visibleFrame: visibleFrame)
    }

    func updatePosition(with settingsFrame: CGRect, visibleFrame: CGRect) {
        guard let window, let frame = targetFrame(settingsFrame: settingsFrame, visibleFrame: visibleFrame) else {
            hide()
            return
        }
        if window.frame != frame { window.setFrame(frame, display: true) }
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func targetFrame(settingsFrame: CGRect, visibleFrame: CGRect) -> CGRect? {
        let visible = visibleFrame.insetBy(dx: 10, dy: 10)
        guard let column = PermissionOverlayPlacement.frame(settings: settingsFrame, visible: visible, height: 1)
        else { return nil }
        if measuredSize?.width != column.width {
            let height: CGFloat
            if let hostingController {
                hostingController.rootView = AnyView(
                    PermissionGrantedGuideView(
                        permission: permission, width: column.width, onClose: onClose
                    ))
                height =
                    hostingController.sizeThatFits(
                        in: NSSize(
                            width: column.width, height: .greatestFiniteMagnitude
                        )
                    ).height
            } else if let content = window?.contentView as? PermissionOverlayContentView {
                height = content.preferredHeight(for: column.width)
            } else {
                return nil
            }
            measuredSize = CGSize(width: column.width, height: ceil(height))
        }
        guard let measuredSize, measuredSize.height > 0 else { return nil }
        return PermissionOverlayPlacement.frame(
            settings: settingsFrame, visible: visible, height: measuredSize.height
        )
    }
}

private final class PassiveOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
