//
//  ScreenshotSettingsTab.swift
//  PeekOCR
//
//  Settings tab for screenshot configuration using modular sections.
//

import SwiftUI

/// Screenshot settings tab composed of reusable section components
struct ScreenshotSettingsTab: View {
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var appSettings = AppSettings.shared

    var body: some View {
        Form {
            HotkeyDisplaySection(appSettings: appSettings)
            SaveOptionsSection(settings: settings)

            if settings.saveToFile {
                SaveLocationSection(settings: settings)
            }

            ImageFormatSection(settings: settings)
            ImageScaleSection(settings: settings)
            AnnotationDefaultsSection(appSettings: appSettings)
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    ScreenshotSettingsTab()
}
