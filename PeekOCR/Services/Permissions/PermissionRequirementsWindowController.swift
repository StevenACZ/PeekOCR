import AppKit
import SwiftUI

@MainActor
final class PermissionRequirementsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PermissionRequirementsWindowController()
    private var hostingView: NSHostingView<PermissionRequirementsView>?
    private var refreshTimer: Timer?
    private var grantedPermissions: Set<AppPermission> = []
    private var language = ""
    private init() {
        super.init(window: nil)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            scheduleRefresh()
            return
        }
        grantedPermissions = Set(AppPermission.allCases.filter { PermissionService.shared.isGranted($0) })
        language = LocalizationManager.shared.language
        guard let size = measureContentSize() else { return }
        let hosting = NSHostingView(rootView: makeContent())
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        hostingView = hosting
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false
        )
        window.title = "permissions.welcome.title".localized
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self
        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        window.contentView = PermissionRequirementsSurface(content: hosting, size: size)
        hosting.sizingOptions = []
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleRefresh()
    }
    func closeWindow() {
        window?.close()
    }

    private func makeContent() -> PermissionRequirementsView {
        PermissionRequirementsView(
            grantedPermissions: grantedPermissions,
            onActivate: { PermissionService.shared.requestInteractively($0) },
            onClose: { [weak self] in self?.closeWindow() }
        )
    }

    private func measureContentSize() -> NSSize? {
        let sizing = NSHostingView(rootView: makeContent())
        sizing.sizingOptions = .intrinsicContentSize
        sizing.safeAreaRegions = []
        let size = sizing.fittingSize
        guard size.height.isFinite, size.height > 0 else { return nil }
        return NSSize(width: PermissionRequirementsView.windowWidth, height: ceil(size.height))
    }

    private func scheduleRefresh() {
        DispatchQueue.main.async { [weak self, weak expectedWindow = window] in
            guard let self, let expectedWindow, self.window === expectedWindow,
                expectedWindow.occlusionState.contains(.visible), !NSApp.isHidden
            else { return }
            self.refresh()
            self.refreshTimer?.invalidate()
            self.refreshTimer = Timer.scheduledTimer(
                timeInterval: 0.5, target: self, selector: #selector(refresh), userInfo: nil, repeats: true
            )
        }
    }

    @objc private func refresh() {
        guard let window, window.occlusionState.contains(.visible), !NSApp.isHidden else {
            refreshTimer?.invalidate()
            refreshTimer = nil
            return
        }
        let granted = Set(AppPermission.allCases.filter { PermissionService.shared.isGranted($0) })
        let currentLanguage = LocalizationManager.shared.language
        guard granted != grantedPermissions || currentLanguage != language else { return }
        grantedPermissions = granted
        language = currentLanguage
        window.title = "permissions.welcome.title".localized
        guard let size = measureContentSize() else { return }
        hostingView?.rootView = makeContent()
        var frame = window.frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        if window.frame != frame { window.setFrame(frame, display: true) }
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        if window?.occlusionState.contains(.visible) == true {
            scheduleRefresh()
        } else {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        PermissionAssistant.shared.dismiss()
        hostingView = nil
        window?.contentView = nil
        window = nil
    }
}

private final class PermissionRequirementsSurface: NSView {
    init(content: NSView, size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { layer?.backgroundColor = permissionCGColor(.windowBackgroundColor) }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
