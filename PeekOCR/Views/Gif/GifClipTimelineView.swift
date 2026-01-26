//
//  GifClipTimelineView.swift
//  PeekOCR
//
//  A timeline control for selecting a trim range and scrubbing a playhead.
//

import SwiftUI

/// Timeline that supports a trim range (in/out) plus a draggable playhead.
struct GifClipTimelineView: View {
    @Binding var startSeconds: Double
    @Binding var endSeconds: Double

    let durationSeconds: Double
    let currentSeconds: Double

    let stepSeconds: Double
    let minimumSelectionSeconds: Double

    var onScrub: (Double) -> Void
    var onBeginEditing: () -> Void

    private let trackHeight: CGFloat = 54
    private let cornerRadius: CGFloat = 12
    private let handleWidth: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let clampedStart = clamp(startSeconds, 0, durationSeconds)
            let clampedEnd = clamp(endSeconds, 0, durationSeconds)

            let startX = x(for: clampedStart, width: width)
            let endX = x(for: clampedEnd, width: width)
            let playheadX = x(for: clamp(currentSeconds, 0, durationSeconds), width: width)

            ZStack(alignment: .leading) {
                trackBackground

                selectionHighlight(startX: startX, endX: endX)

                playhead(x: playheadX)

                handle(isLeading: true, x: startX)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onBeginEditing()
                                updateLeadingHandle(locationX: gesture.location.x, width: width)
                            }
                    )

                handle(isLeading: false, x: endX)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onBeginEditing()
                                updateTrailingHandle(locationX: gesture.location.x, width: width)
                            }
                    )
            }
            .frame(height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onBeginEditing()
                        let seconds = seconds(for: gesture.location.x, width: width)
                        onScrub(snap(seconds))
                    }
            )
        }
        .frame(height: trackHeight)
    }

    private var trackBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func selectionHighlight(startX: CGFloat, endX: CGFloat) -> some View {
        let left = min(startX, endX)
        let right = max(startX, endX)
        return RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
            .fill(Color.yellow.opacity(0.85))
            .frame(width: max(0, right - left), height: trackHeight - 10)
            .padding(.vertical, 5)
            .offset(x: left)
            .allowsHitTesting(false)
    }

    private func playhead(x: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 2, height: trackHeight - 10)
            .padding(.vertical, 5)
            .offset(x: x - 1)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            .allowsHitTesting(false)
    }

    private func handle(isLeading: Bool, x: CGFloat) -> some View {
        let offsetX = x - handleWidth / 2
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.yellow.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 3) {
                Rectangle().fill(Color.black.opacity(0.55)).frame(width: 2, height: 18)
                Rectangle().fill(Color.black.opacity(0.55)).frame(width: 2, height: 18)
            }
        }
        .frame(width: handleWidth, height: trackHeight - 14)
        .padding(.vertical, 7)
        .offset(x: offsetX)
        .accessibilityLabel(isLeading ? "Inicio" : "Fin")
    }

    private func updateLeadingHandle(locationX: CGFloat, width: CGFloat) {
        guard durationSeconds > 0 else { return }
        let seconds = snap(seconds(for: locationX, width: width))
        let maxStart = max(0, min(durationSeconds, endSeconds - minimumSelectionSeconds))
        startSeconds = clamp(seconds, 0, maxStart)
        onScrub(startSeconds)
    }

    private func updateTrailingHandle(locationX: CGFloat, width: CGFloat) {
        guard durationSeconds > 0 else { return }
        let seconds = snap(seconds(for: locationX, width: width))
        let minEnd = min(durationSeconds, startSeconds + minimumSelectionSeconds)
        endSeconds = clamp(seconds, minEnd, durationSeconds)
        onScrub(endSeconds)
    }

    private func snap(_ seconds: Double) -> Double {
        guard stepSeconds > 0 else { return seconds }
        return (seconds / stepSeconds).rounded() * stepSeconds
    }

    private func seconds(for x: CGFloat, width: CGFloat) -> Double {
        guard durationSeconds > 0 else { return 0 }
        let clampedX = min(max(0, x), width)
        return (Double(clampedX / width) * durationSeconds)
    }

    private func x(for seconds: Double, width: CGFloat) -> CGFloat {
        guard durationSeconds > 0 else { return 0 }
        return CGFloat(seconds / durationSeconds) * width
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}

#Preview {
    GifClipTimelinePreviewWrapper()
        .padding()
        .frame(width: 720)
        .background(Color.black.opacity(0.2))
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
            stepSeconds: 0.1,
            minimumSelectionSeconds: 3,
            onScrub: { current = $0 },
            onBeginEditing: {}
        )
    }
}
