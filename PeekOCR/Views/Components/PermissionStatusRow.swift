import AppKit
import SwiftUI

struct PermissionStatusRow: View {
    let permission: AppPermission
    @State private var isGranted = false

    private var accent: Color { Color(nsColor: permission.accentColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(permission.title, systemImage: permission.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("permissions.card.status.granted".localized)
                } else {
                    Button("permissions.enable".localized) {
                        PermissionService.shared.flow?.present()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(accent)
                }
            }
            Text(permission.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .onAppear { refreshPermissionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        isGranted = PermissionService.shared.isGranted(permission)
    }
}
