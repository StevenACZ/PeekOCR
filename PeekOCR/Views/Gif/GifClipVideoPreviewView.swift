//
//  GifClipVideoPreviewView.swift
//  PeekOCR
//
//  Video preview container with a playback controls row under the video.
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
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(vignette)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            VStack(spacing: 10) {
                NonInteractiveVideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                .frame(maxWidth: 460)
            }
            .padding([.top, .horizontal], 14)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var vignette: RadialGradient {
        RadialGradient(
            colors: [
                Color.white.opacity(0.04),
                Color.black.opacity(0.0),
                Color.black.opacity(0.25),
            ],
            center: .center,
            startRadius: 0,
            endRadius: 900
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
