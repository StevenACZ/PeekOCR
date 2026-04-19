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
    let isCaptureDisabled: Bool

    var onTogglePlay: () -> Void
    var onStepBackward: () -> Void
    var onStepForward: () -> Void
    var onCaptureFrame: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            playButton

            Text("\(format(currentSeconds)) / \(format(durationSeconds))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize()

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                stepButton(
                    symbol: "backward.frame.fill",
                    action: onStepBackward,
                    help: "Frame anterior  (←)"
                )
                stepButton(
                    symbol: "forward.frame.fill",
                    action: onStepForward,
                    help: "Frame siguiente  (→)"
                )
            }

            Divider()
                .frame(height: 18)
                .opacity(0.4)

            Button(action: onCaptureFrame) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(isCaptureDisabled)
            .help("Guardar frame actual como imagen")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
    }

    private var playButton: some View {
        Button(action: onTogglePlay) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help(isPlaying ? "Pausar  (Espacio)" : "Reproducir  (Espacio)")
    }

    private func stepButton(symbol: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
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
        Color.black
        GifClipPlaybackControlsView(
            isPlaying: false,
            currentSeconds: 3.5,
            durationSeconds: 9.2,
            isCaptureDisabled: false,
            onTogglePlay: {},
            onStepBackward: {},
            onStepForward: {},
            onCaptureFrame: {}
        )
        .padding()
    }
    .frame(width: 460, height: 160)
}
