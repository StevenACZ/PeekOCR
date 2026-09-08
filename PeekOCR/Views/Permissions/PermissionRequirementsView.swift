import SwiftUI

struct PermissionRequirementsView: View {
    static let windowWidth: CGFloat = 480
    @ObservedObject private var localization = LocalizationManager.shared

    let grantedPermissions: Set<AppPermission>
    let onActivate: (AppPermission) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionRequirementsIntroView(missingCount: missingCount)
            ForEach(AppPermission.allCases, id: \.self) { permission in
                PermissionRequirementCard(
                    permission: permission,
                    isGranted: grantedPermissions.contains(permission),
                    onActivate: onActivate
                )
            }
            HStack {
                Spacer(minLength: 0)
                Button((missingCount == 0 ? "permissions.welcome.done" : "permissions.window.not_now").localized) {
                    onClose()
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .keyboardShortcut(.cancelAction)
            }
        }
        .id(localization.language)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 20)
        .frame(width: Self.windowWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    }

    private var missingCount: Int {
        AppPermission.allCases.count - grantedPermissions.count
    }
}
