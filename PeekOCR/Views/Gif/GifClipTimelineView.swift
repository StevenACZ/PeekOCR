//
//  GifClipTimelineView.swift
//  PeekOCR
//
//  A timeline control for selecting a trim range and scrubbing a playhead.
//

import SwiftUI

/// Timeline that supports a trim range (in/out) plus a draggable playhead.
struct GifClipTimelineView: View {
    private enum DragHandle {
        case start
        case end
    }

    @Binding var startSeconds: Double
    @Binding var endSeconds: Double

    let durationSeconds: Double
    let currentSeconds: Double
    let isPlaying: Bool
    let frames: [CGImage?]

    let stepSeconds: Double
    let minimumSelectionSeconds: Double

    var onScrub: (Double) -> Void
    var onBeginEditing: () -> Void

    static let trackHeight: CGFloat = 64
    private let cornerRadius: CGFloat = 10
    private let handleWidth: CGFloat = 12

    private struct DragState {
        let handle: DragHandle
        let initialStartSeconds: Double
        let initialEndSeconds: Double
    }

    @State private var dragState: DragState?
    @State private var isScrubbing = false
    @State private var hoverX: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let startX = x(for: clamp(startSeconds, 0, durationSeconds), width: width)
            let endX = x(for: clamp(endSeconds, 0, durationSeconds), width: width)
            let playheadX = x(for: clamp(currentSeconds, 0, durationSeconds), width: width)

            ZStack(alignment: .leading) {
                filmstrip(width: width)
                dimming(startX: startX, endX: endX, width: width)
                tickMarks(width: width)
                selectionFrame(startX: startX, endX: endX)
                handle(.start, x: startX, width: width)
                handle(.end, x: endX, width: width)
                playhead(x: playheadX)
                    .animation(isPlaying && !reduceMotion ? .linear(duration: 0.05) : nil, value: playheadX)
                if let label = floatingLabel(startX: startX, endX: endX, width: width) {
                    timeLabel(label.text)
                        .offset(x: label.x, y: 6)
                        .transition(.opacity)
                }
            }
            .frame(height: Self.trackHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): hoverX = point.x
                case .ended: hoverX = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard dragState == nil else { return }
                        onBeginEditing()
                        isScrubbing = true
                        hoverX = gesture.location.x
                        onScrub(snap(seconds(for: gesture.location.x, width: width)))
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        hoverX = nil
                    }
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: dragState?.handle == nil)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hoverX == nil)
        }
        .frame(height: Self.trackHeight)
    }

    private func filmstrip(width: CGFloat) -> some View {
        let count = max(1, frames.count)
        let cell = width / CGFloat(count)
        return HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                ZStack {
                    Color.primary.opacity(0.06)
                    if let frame = frames.indices.contains(index) ? frames[index] : nil {
                        Image(decorative: frame, scale: 1)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    }
                }
                .frame(width: cell, height: Self.trackHeight)
                .clipped()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: frames.compactMap { $0 }.count)
        .allowsHitTesting(false)
    }

    private func dimming(startX: CGFloat, endX: CGFloat, width: CGFloat) -> some View {
        let left = min(startX, endX)
        let right = max(startX, endX)
        return ZStack(alignment: .leading) {
            Rectangle().fill(.black.opacity(0.55))
                .frame(width: max(0, left))
            Rectangle().fill(.black.opacity(0.55))
                .frame(width: max(0, width - right))
                .offset(x: right)
        }
        .allowsHitTesting(false)
    }

    private func tickMarks(width: CGFloat) -> some View {
        let count = max(0, Int(durationSeconds))
        return ZStack(alignment: .leading) {
            ForEach(1..<max(1, count + 1), id: \.self) { second in
                Rectangle()
                    .fill(.white.opacity(second % 5 == 0 ? 0.55 : 0.3))
                    .frame(width: 1, height: second % 5 == 0 ? 8 : 5)
                    .offset(x: x(for: Double(second), width: width) - 0.5, y: Self.trackHeight / 2 - (second % 5 == 0 ? 4 : 2.5))
            }
        }
        .allowsHitTesting(false)
    }

    private func selectionFrame(startX: CGFloat, endX: CGFloat) -> some View {
        let left = min(startX, endX)
        let right = max(startX, endX)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 2.5)
            .frame(width: max(0, right - left), height: Self.trackHeight)
            .offset(x: left)
            .allowsHitTesting(false)
    }

    private func playhead(x: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.white)
                .frame(width: 10, height: 6)
            Rectangle()
                .fill(.white)
                .frame(width: 2)
        }
        .frame(height: Self.trackHeight)
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
        .offset(x: x - 5)
        .zIndex(11)
        .allowsHitTesting(false)
    }

    private func handle(_ kind: DragHandle, x: CGFloat, width: CGFloat) -> some View {
        let isActive = dragState?.handle == kind
        let offsetX = kind == .start ? x : x - handleWidth
        let clampedOffsetX = min(max(0, offsetX), max(0, width - handleWidth))
        return ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: kind == .start ? 6 : 0, bottomLeadingRadius: kind == .start ? 6 : 0,
                bottomTrailingRadius: kind == .end ? 6 : 0, topTrailingRadius: kind == .end ? 6 : 0, style: .continuous
            )
            .fill(Color.accentColor)
            Capsule()
                .fill(.white.opacity(isActive ? 1 : 0.8))
                .frame(width: 2, height: 16)
        }
        .frame(width: handleWidth, height: Self.trackHeight)
        .scaleEffect(isActive && !reduceMotion ? 1.06 : 1, anchor: kind == .start ? .leading : .trailing)
        .contentShape(Rectangle().inset(by: -6))
        .offset(x: clampedOffsetX)
        .zIndex(10)
        .onHover { inside in
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    onBeginEditing()
                    if dragState == nil {
                        dragState = DragState(handle: kind, initialStartSeconds: startSeconds, initialEndSeconds: endSeconds)
                    }
                    updateHandle(kind, translationX: gesture.translation.width, width: width)
                }
                .onEnded { _ in
                    dragState = nil
                    hoverX = nil
                }
        )
        .accessibilityLabel(kind == .start ? "clip_editor.start".localized : "clip_editor.end".localized)
    }

    private func floatingLabel(startX: CGFloat, endX: CGFloat, width: CGFloat) -> (text: String, x: CGFloat)? {
        let anchorX: CGFloat
        let seconds: Double
        if let dragState {
            anchorX = dragState.handle == .start ? startX : endX
            seconds = dragState.handle == .start ? startSeconds : endSeconds
        } else if let hoverX, hoverX >= 0, hoverX <= width {
            anchorX = hoverX
            seconds = isScrubbing ? currentSeconds : self.seconds(for: hoverX, width: width)
        } else {
            return nil
        }
        let labelWidth: CGFloat = 58
        return (formatSeconds(seconds), min(max(4, anchorX - labelWidth / 2), width - labelWidth - 4))
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.65), in: Capsule())
            .frame(width: 58)
            .allowsHitTesting(false)
            .zIndex(20)
    }

    private func updateHandle(_ handle: DragHandle, translationX: CGFloat, width: CGFloat) {
        guard durationSeconds > 0, width > 0, let dragState else { return }
        let deltaSeconds = Double(translationX / width) * durationSeconds
        switch handle {
        case .start:
            let proposed = snap(dragState.initialStartSeconds + deltaSeconds)
            let maxStart = max(0, min(durationSeconds, dragState.initialEndSeconds - minimumSelectionSeconds))
            startSeconds = clamp(proposed, 0, maxStart)
            onScrub(startSeconds)
        case .end:
            let proposed = snap(dragState.initialEndSeconds + deltaSeconds)
            let minEnd = min(durationSeconds, dragState.initialStartSeconds + minimumSelectionSeconds)
            endSeconds = clamp(proposed, minEnd, durationSeconds)
            onScrub(endSeconds)
        }
    }

    private func snap(_ seconds: Double) -> Double {
        guard stepSeconds > 0 else { return seconds }
        return (seconds / stepSeconds).rounded() * stepSeconds
    }

    private func seconds(for x: CGFloat, width: CGFloat) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(min(max(0, x), width) / width) * durationSeconds
    }

    private func x(for seconds: Double, width: CGFloat) -> CGFloat {
        guard durationSeconds > 0 else { return 0 }
        return CGFloat(seconds / durationSeconds) * width
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00.0" }
        let clamped = max(0, seconds)
        let minutes = Int(clamped / 60)
        return String(format: "%02d:%04.1f", minutes, clamped - Double(minutes * 60))
    }
}

#Preview {
    GifClipTimelinePreviewWrapper()
        .padding()
        .frame(width: 720)
        .background(Color(NSColor.windowBackgroundColor))
}

private struct GifClipTimelinePreviewWrapper: View {
    @State private var start: Double = 1.2
    @State private var end: Double = 5.4
    @State private var current: Double = 3.5

    var body: some View {
        GifClipTimelineView(
            startSeconds: $start,
            endSeconds: $end,
            durationSeconds: 9.2,
            currentSeconds: current,
            isPlaying: false,
            frames: Array(repeating: nil, count: GifClipFilmstrip.frameCount),
            stepSeconds: 0.1,
            minimumSelectionSeconds: 3,
            onScrub: { current = $0 },
            onBeginEditing: {}
        )
    }
}
