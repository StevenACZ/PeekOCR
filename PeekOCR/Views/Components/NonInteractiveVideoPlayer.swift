//
//  NonInteractiveVideoPlayer.swift
//  PeekOCR
//
//  Wraps AVPlayerView with controls disabled for preview-only playback.
//

import SwiftUI
import AVKit

/// Preview-only AVPlayerView without built-in playback controls.
struct NonInteractiveVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = NonInteractiveAVPlayerView()
        view.controlsStyle = .none
        view.player = player
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

private final class NonInteractiveAVPlayerView: AVPlayerView {
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
}

