//
//  GifClipPlaybackControlsView.swift
//  PeekOCR
//
//  Playback controls overlay for the GIF clip editor video preview.
//

import SwiftUI

/// Playback controls shown over the video (play/pause, time, frame stepping).
struct GifClipPlaybackControlsView: View {
    let isPlaying: Bool
    let currentSeconds: Double
    let durationSeconds: Double

    var onTogglePlay: () -> Void
    var onStepBackward: () -> Void
    var onStepForward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text("\(format(currentSeconds)) / \(format(durationSeconds))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button(action: onStepBackward) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Frame anterior (←)")

            Button(action: onStepForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Frame siguiente (→)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00.0" }
        let clamped = max(0, seconds)
        let minutes = Int(clamped / 60)
        let secs = clamped - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, secs)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        GifClipPlaybackControlsView(
            isPlaying: false,
            currentSeconds: 3.5,
            durationSeconds: 9.2,
            onTogglePlay: {},
            onStepBackward: {},
            onStepForward: {}
        )
        .padding()
    }
    .frame(width: 420, height: 160)
}

