import SwiftUI

struct PermissionRequirementCard: View {
    let permission: AppPermission
    let isGranted: Bool
    let onActivate: (AppPermission) -> Void

    private var accent: Color { Color(nsColor: permission.accentColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(permission.title, systemImage: permission.iconName)
                    .font(.headline)
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                if isGranted {
                    Label("permissions.card.status.granted".localized, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
            Text(permission.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if isGranted && permission == .screenRecording {
                Text("permissions.screen_recording.restart_hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isGranted {
                Button {
                    onActivate(permission)
                } label: {
                    Text("permissions.card.activate".localized)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(accent, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(.white)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }
}
