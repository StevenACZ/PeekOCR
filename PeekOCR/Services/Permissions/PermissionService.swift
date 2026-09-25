//
//  PermissionService.swift
//  PeekOCR
//
//  Centralizes permission checks and hosts the first-run permission flow.
//

import AppKit

/// Central permission service used by settings and feature entry points.
final class PermissionService {
    static let shared = PermissionService()

    @MainActor var flow: PermissionFlow?

    private init() {}

    func isGranted(_ permission: AppPermission) -> Bool {
        permission.isGranted()
    }

    func missingPermissions() -> [AppPermission] {
        AppPermission.allCases.filter { permission in
            !permission.isGranted()
        }
    }
}
