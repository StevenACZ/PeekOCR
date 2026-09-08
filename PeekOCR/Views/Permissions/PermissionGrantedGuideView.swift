import SwiftUI

struct PermissionGrantedGuideView: View {
    let permission: AppPermission
    let width: CGFloat
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("permissions.welcome.granted".localized, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(
                permission == .screenRecording
                    ? "permissions.screen_recording.restart_hint".localized
                    : "permissions.guide.granted".localized
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer(minLength: 0)
                Button("permissions.welcome.done".localized, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .padding(20)
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
    }
}
