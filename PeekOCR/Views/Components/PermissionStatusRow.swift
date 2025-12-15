//
//  PermissionStatusRow.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import SwiftUI

/// A reusable row component for displaying permission status
struct PermissionStatusRow: View {
    let title: String
    let description: String
    let icon: String
    let checkPermission: () -> Bool
    let openSettings: () -> Void

    @State private var isGranted = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Activar") {
                    openSettings()
                }
                .buttonStyle(.link)
            }
        }
        .onAppear {
            isGranted = checkPermission()
        }
    }
}
