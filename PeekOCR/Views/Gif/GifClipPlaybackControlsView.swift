//
//  GifClipPlaybackControlsView.swift
//  PeekOCR
//
//  Playback controls row for the GIF clip editor video preview.
//

import SwiftUI

/// Playback controls shown under the video (play/pause, time, frame stepping).
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
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize()

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                stepButton(
                    symbol: "backward.frame.fill",
                    action: onStepBackward,
                    help: "clip_editor.step_backward_help".localized
                )
                stepButton(
                    symbol: "forward.frame.fill",
                    action: onStepForward,
                    help: "clip_editor.step_forward_help".localized
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
            .help("clip_editor.capture_frame_help".localized)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private var playButton: some View {
        Button(action: onTogglePlay) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Color.white.opacity(isPlaying ? 0.2 : 0.12))
                )
                .animation(.easeOut(duration: 0.18), value: isPlaying)
        }
        .buttonStyle(.plain)
        .help(isPlaying ? "clip_editor.pause_help".localized : "clip_editor.play_help".localized)
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
