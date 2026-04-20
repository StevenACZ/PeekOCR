//
//  PermissionRequirementsView.swift
//  PeekOCR
//
//  Explains which permissions are missing before capture actions can continue.
//

import AppKit
import SwiftUI

/// Modal content shown when required permissions are still missing.
struct PermissionRequirementsView: View {
    static let windowSize = CGSize(width: 500, height: 480)

    let onActivate: (AppPermission) -> Void
    let onClose: () -> Void
    private let previewPermissions: [AppPermission]?

    @State private var missingPermissions: [AppPermission] = []

    init(
        previewPermissions: [AppPermission]? = nil,
        onActivate: @escaping (AppPermission) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.previewPermissions = previewPermissions
        self.onActivate = onActivate
        self.onClose = onClose
        _missingPermissions = State(initialValue: previewPermissions ?? [])
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 14) {
                PermissionRequirementsIntroView(missingCount: missingPermissions.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(missingPermissions.enumerated()), id: \.element) { index, permission in
                        PermissionRequirementCard(
                            permission: permission,
                            index: index + 1,
                            isLast: index == missingPermissions.count - 1,
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
            refreshMissingPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshMissingPermissions()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Circle()
                .fill(Color.orange.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: -110, y: -120)

            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 180, y: 120)
        }
        .ignoresSafeArea()
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            Label("Puedes cerrar esta ventana y volver luego.", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Ahora no") {
                onClose()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var sectionTitle: String {
        switch missingPermissions.count {
        case 0:
            return "Sin pendientes"
        case 1:
            return "Permiso pendiente"
        default:
            return "Permisos pendientes"
        }
    }

    private func refreshMissingPermissions() {
        if let previewPermissions {
            missingPermissions = previewPermissions
            return
        }

        let updatedPermissions = PermissionService.shared.missingPermissions()
        missingPermissions = updatedPermissions

        if updatedPermissions.isEmpty {
            onClose()
        }
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
            previewPermissions: [.screenRecording, .accessibility],
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
