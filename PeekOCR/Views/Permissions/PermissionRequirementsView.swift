//
//  PermissionRequirementsView.swift
//  PeekOCR
//
//  Explains which permissions are missing before capture actions can continue.
//

import AppKit
import Combine
import SwiftUI

/// Modal content shown when required permissions are still missing.
struct PermissionRequirementsView: View {
    static let windowSize = CGSize(width: 500, height: 480)

    let onActivate: (AppPermission) -> Void
    let onClose: () -> Void
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let previewGrantedPermissions: Set<AppPermission>?

    @Environment(\.colorScheme) private var colorScheme
    @State private var grantedPermissions: Set<AppPermission> = []

    init(
        previewGrantedPermissions: Set<AppPermission>? = nil,
        onActivate: @escaping (AppPermission) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.previewGrantedPermissions = previewGrantedPermissions
        self.onActivate = onActivate
        self.onClose = onClose
        _grantedPermissions = State(initialValue: previewGrantedPermissions ?? [])
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 14) {
                PermissionRequirementsIntroView(missingCount: missingCount)

                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(AppPermission.allCases.enumerated()), id: \.element) { index, permission in
                        PermissionRequirementCard(
                            permission: permission,
                            index: index + 1,
                            isLast: index == AppPermission.allCases.count - 1,
                            isGranted: grantedPermissions.contains(permission),
                            onActivate: onActivate
                        )
                    }
                }

                Color.clear.frame(height: 6)
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshPermissionStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatuses()
        }
        .onReceive(refreshTimer) { _ in
            refreshPermissionStatuses()
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.42 : 0.72),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            Label(footerMessage, systemImage: footerIconName)
                .font(.caption)
                .foregroundStyle(footerColor)

            Spacer()

            Button(footerButtonTitle) {
                onClose()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var sectionTitle: String {
        "Permisos del sistema"
    }

    private var missingCount: Int {
        AppPermission.allCases.filter { !grantedPermissions.contains($0) }.count
    }

    private var footerMessage: String {
        if missingCount == 0 {
            return "Ya puedes cerrar esta ventana y continuar con PeekOCR."
        }

        return "Puedes cerrar esta ventana y volver luego."
    }

    private var footerIconName: String {
        missingCount == 0
            ? "checkmark.circle.fill"
            : "clock.arrow.trianglehead.counterclockwise.rotate.90"
    }

    private var footerColor: Color {
        missingCount == 0 ? .green : .secondary
    }

    private var footerButtonTitle: String {
        missingCount == 0 ? "Cerrar" : "Ahora no"
    }

    private func refreshPermissionStatuses() {
        if let previewGrantedPermissions {
            grantedPermissions = previewGrantedPermissions
            return
        }

        grantedPermissions = Set(AppPermission.allCases.filter { PermissionService.shared.isGranted($0) })
    }
}

struct PermissionRequirementsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionRequirementsPreviewCanvas()
            .previewLayout(.sizeThatFits)
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PermissionRequirementsPreviewCanvas: View {
    var body: some View {
        PermissionRequirementsView(
            previewGrantedPermissions: [.screenRecording],
            onActivate: { _ in },
            onClose: {}
        )
        .frame(
            width: PermissionRequirementsView.windowSize.width,
            height: PermissionRequirementsView.windowSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}
