//
//  ScreenCaptureService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import ScreenCaptureKit

/// Service for capturing screen regions
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Capture a specific region of the screen
    /// - Parameter rect: The rectangle to capture in screen coordinates
    /// - Returns: The captured image or nil if capture failed
    func captureRegion(_ rect: CGRect) async -> CGImage? {
        // Ensure we have permissions
        guard await hasScreenCapturePermission() else {
            requestScreenCapturePermission()
            return nil
        }
        
        // Use CGWindowListCreateImage for direct capture
        let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .nominalResolution]
        )
        
        return image
    }
    
    /// Capture all screens at once
    /// - Returns: Dictionary of display ID to captured image
    func captureAllScreens() -> [CGDirectDisplayID: CGImage] {
        var captures: [CGDirectDisplayID: CGImage] = [:]
        
        let displays = getActiveDisplays()
        for displayID in displays {
            let bounds = CGDisplayBounds(displayID)
            if let image = CGWindowListCreateImage(
                bounds,
                .optionOnScreenBelowWindow,
                kCGNullWindowID,
                [.boundsIgnoreFraming, .nominalResolution]
            ) {
                captures[displayID] = image
            }
        }
        
        return captures
    }
    
    /// Get the bounds of all active displays
    /// - Returns: Array of display bounds
    func getDisplayBounds() -> [CGRect] {
        return getActiveDisplays().map { CGDisplayBounds($0) }
    }
    
    // MARK: - Permission Handling
    
    func hasScreenCapturePermission() async -> Bool {
        do {
            // Try to get shareable content - this will fail if no permission
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
    
    func requestScreenCapturePermission() {
        // Open System Preferences to Screen Recording
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func getActiveDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        return displays
    }
}
