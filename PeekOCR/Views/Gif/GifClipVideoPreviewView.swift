//
//  GifClipVideoPreviewView.swift
//  PeekOCR
//
//  Video preview container with a colorful background and playback controls overlay.
//

import AVKit
import SwiftUI

/// Video preview used by the GIF clip editor.
struct GifClipVideoPreviewView: View {
    let player: AVPlayer
    let isPlaying: Bool
    let currentSeconds: Double
    let durationSeconds: Double
    let isCaptureFrameDisabled: Bool

    var onTogglePlay: () -> Void
    var onStepBackward: () -> Void
    var onStepForward: () -> Void
    var onCaptureFrame: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            NonInteractiveVideoPlayer(player: player)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(16)

            VStack {
                Spacer()
                GifClipPlaybackControlsView(
                    isPlaying: isPlaying,
                    currentSeconds: currentSeconds,
                    durationSeconds: durationSeconds,
                    isCaptureDisabled: isCaptureFrameDisabled,
                    onTogglePlay: onTogglePlay,
                    onStepBackward: onStepBackward,
                    onStepForward: onStepForward,
                    onCaptureFrame: onCaptureFrame
                )
                .frame(maxWidth: 420)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.45, blue: 0.30),
                Color(red: 0.25, green: 0.55, blue: 0.95),
                Color(red: 0.60, green: 0.25, blue: 0.85),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    GifClipVideoPreviewView(
        player: AVPlayer(),
        isPlaying: false,
        currentSeconds: 3.5,
        durationSeconds: 9.2,
        isCaptureFrameDisabled: false,
        onTogglePlay: {},
        onStepBackward: {},
        onStepForward: {},
        onCaptureFrame: {}
    )
    .frame(width: 720, height: 420)
}
