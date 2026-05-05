//
//  ShortcutRecorderRow.swift
//  PeekOCR
//
//  Created by Steven on 14/12/25.
//

import Carbon
import SwiftUI

/// A reusable row component for recording keyboard shortcuts
struct ShortcutRecorderRow: View {
    let title: String
    let description: String
    let icon: String
    let currentShortcut: String
    let onRecord: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var recordingTimeoutWorkItem: DispatchWorkItem?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecording {
                recordingIndicator
            } else {
                shortcutDisplay
            }
        }
        .padding(.vertical, 4)
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Subviews

    private var recordingIndicator: some View {
        Text("Presiona una tecla...")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var shortcutDisplay: some View {
        HStack(spacing: 8) {
            Text(currentShortcut)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Button("Grabar") {
                startRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        stopRecording()
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else {
                return event
            }

            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async {
                    stopRecording()
                }
                return nil
            }

            let modifiers = HotKeyDisplay.carbonModifiers(from: event.modifierFlags)
            let keyCode = UInt32(event.keyCode)

            // Require at least one modifier
            guard modifiers != 0 else {
                return nil  // Consume the event while recording
            }

            DispatchQueue.main.async {
                stopRecording()
                onRecord(modifiers, keyCode)
            }

            return nil  // Consume the event
        }

        let timeout = DispatchWorkItem {
            stopRecording()
        }
        recordingTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
    }

    private func stopRecording() {
        isRecording = false

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        recordingTimeoutWorkItem?.cancel()
        recordingTimeoutWorkItem = nil
    }
}
