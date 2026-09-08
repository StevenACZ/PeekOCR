import SwiftUI

struct PermissionRequirementsIntroView: View {
    let missingCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: PermissionHostApp.current().icon)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text("permissions.welcome.title".localized)
                    .font(.title2.weight(.bold))
                Text((missingCount == 0 ? "permissions.welcome.granted" : "permissions.welcome.subtitle").localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
