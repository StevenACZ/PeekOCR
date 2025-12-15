//
//  LaunchAtLoginManager.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import ServiceManagement
import Foundation

/// Manages the launch at login setting using SMAppService
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    // MARK: - Properties
    
    private let service = SMAppService.mainApp
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if the app is set to launch at login
    var isEnabled: Bool {
        return service.status == .enabled
    }
    
    /// Set whether the app should launch at login
    /// - Parameter enabled: True to enable launch at login
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
    
    /// Get the current status
    var status: SMAppService.Status {
        return service.status
    }
}
