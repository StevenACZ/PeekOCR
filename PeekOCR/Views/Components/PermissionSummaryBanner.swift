//
//  PermissionSummaryBanner.swift
//  PeekOCR
//
//  Highlights missing permissions at the top of the menu bar popover.
//

import SwiftUI

/// Compact warning banner for pending macOS permissions.
struct PermissionSummaryBanner: View {
    let missingPermissions: [AppPermission]
    let onReview: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Permisos pendientes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Activa \(permissionListText) para usar PeekOCR por completo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("Revisar") {
                onReview()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(colorScheme == .dark ? 0.24 : 0.16), lineWidth: 1)
                )
        )
    }

    private var permissionListText: String {
        let titles = missingPermissions.map(\.title)

        switch titles.count {
        case 0:
            return "los permisos"
        case 1:
            return titles[0]
        case 2:
            return "\(titles[0]) y \(titles[1])"
        default:
            let head = titles.dropLast().joined(separator: ", ")
            return "\(head) y \(titles.last ?? "")"
        }
    }
}
