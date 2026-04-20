//
//  PermissionService.swift
//  PeekOCR
//
//  Centralizes permission checks, native prompts, and the guided assistant flow.
//

import AppKit
import os

/// Central permission service used by settings and feature entry points.
final class PermissionService {
    static let shared = PermissionService()

    private init() {}

    func isGranted(_ permission: AppPermission) -> Bool {
        permission.isGranted()
    }

    func missingPermissions() -> [AppPermission] {
        AppPermission.allCases.filter { permission in
            !permission.isGranted()
        }
    }

    func requestInteractively(_ permission: AppPermission, sourceFrameInScreen: CGRect? = nil) {
        guard !permission.isGranted() else { return }

        AppLogger.ui.info("Starting guided permission flow: \(permission.title)")

        let sourceFrame = sourceFrameInScreen ?? Self.mouseSourceRect()
        Task { @MainActor in
            PermissionAssistant.shared.present(
                permission: permission,
                sourceFrameInScreen: sourceFrame
            )
        }
    }

    private static func mouseSourceRect() -> CGRect {
        let point = NSEvent.mouseLocation
        return CGRect(x: point.x - 36, y: point.y - 20, width: 72, height: 40)
    }
}
