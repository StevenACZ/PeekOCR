import AppKit

final class PermissionOverlayCardContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundAlpha: CGFloat = permissionUsesDarkAppearance ? 0.94 : 0.98
        let borderAlpha: CGFloat = permissionUsesDarkAppearance ? 0.26 : 0.16
        layer?.backgroundColor = permissionCGColor(.windowBackgroundColor, alpha: backgroundAlpha)
        layer?.borderColor = permissionCGColor(.separatorColor, alpha: borderAlpha)
    }
}
