//
//  NativeScreenCaptureService.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import AppKit
import Foundation

/// Service that uses macOS native screencapture command for high-quality, reliable captures
final class NativeScreenCaptureService {
    static let shared = NativeScreenCaptureService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Capture a screen region using macOS native screencapture tool
    /// This uses the interactive mode (-i) which provides a smooth, native experience
    /// - Returns: The captured image, or nil if cancelled or failed
    func captureInteractive() async -> CGImage? {
        // Create a temporary file path
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Run screencapture command
        let success = await runScreenCapture(outputPath: tempURL.path)
        
        guard success else { return nil }
        
        // Load the captured image
        guard let imageSource = CGImageSourceCreateWithURL(tempURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        return image
    }
    
    /// Capture a screen region and return the image data directly
    /// - Returns: PNG data of the captured image, or nil if cancelled
    func captureInteractiveAsData() async -> Data? {
        // Create a temporary file path
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        
        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Run screencapture command
        let success = await runScreenCapture(outputPath: tempURL.path)
        
        guard success else { return nil }
        
        // Read the file data
        return try? Data(contentsOf: tempURL)
    }
    
    /// Capture to clipboard directly using native screencapture
    func captureToClipboard() async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive mode, -c: capture to clipboard
            process.arguments = ["-i", "-c"]
            
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            
            do {
                try process.run()
            } catch {
                print("Failed to run screencapture: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    /// Capture and save directly to a file
    /// - Parameter outputPath: Path where to save the image
    /// - Returns: True if capture was successful
    func captureToFile(outputPath: String) async -> Bool {
        return await runScreenCapture(outputPath: outputPath)
    }
    
    // MARK: - Private Methods
    
    private func runScreenCapture(outputPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive mode
            // -s: only allow selection (not fullscreen/window)
            // -x: no sound
            process.arguments = ["-i", "-s", outputPath]
            
            process.terminationHandler = { process in
                // Check if file was created (user didn't cancel)
                let fileExists = FileManager.default.fileExists(atPath: outputPath)
                continuation.resume(returning: process.terminationStatus == 0 && fileExists)
            }
            
            do {
                try process.run()
            } catch {
                print("Failed to run screencapture: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
}
