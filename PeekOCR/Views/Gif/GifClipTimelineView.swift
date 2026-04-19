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

    let stepSeconds: Double
    let minimumSelectionSeconds: Double

    var onScrub: (Double) -> Void
    var onBeginEditing: () -> Void

    private let trackHeight: CGFloat = 40
    private let cornerRadius: CGFloat = 8
    private let handleWidth: CGFloat = 14
    private let selectionInset: CGFloat = 2

    private struct DragState {
        let initialStartSeconds: Double
        let initialEndSeconds: Double
    }

    @State private var dragState: DragState?

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

                tickMarks(width: width)

                selectionHighlight(startX: startX, endX: endX)

                playhead(x: playheadX)

                handle(isLeading: true, x: startX, width: width)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onBeginEditing()
                                beginDragIfNeeded()
                                updateHandle(.start, translationX: gesture.translation.width, width: width)
                            }
                            .onEnded { _ in
                                dragState = nil
                            }
                    )

                handle(isLeading: false, x: endX, width: width)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onBeginEditing()
                                beginDragIfNeeded()
                                updateHandle(.end, translationX: gesture.translation.width, width: width)
                            }
                            .onEnded { _ in
                                dragState = nil
                            }
                    )
            }
            .frame(height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard dragState == nil else { return }
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
            .fill(Color.primary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
    }

    private func tickMarks(width: CGFloat) -> some View {
        let seconds = max(0, durationSeconds)
        guard seconds > 0 else { return AnyView(EmptyView()) }
        let count = max(0, Int(seconds))
        return AnyView(
            ZStack(alignment: .leading) {
                ForEach(1..<count + 1, id: \.self) { i in
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 6)
                        .offset(x: x(for: Double(i), width: width) - 0.5, y: trackHeight / 2 - 3)
                }
            }
            .allowsHitTesting(false)
        )
    }

    private func selectionHighlight(startX: CGFloat, endX: CGFloat) -> some View {
        let left = min(startX, endX)
        let right = max(startX, endX)
        return RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
            .fill(Color.accentColor.opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .frame(width: max(0, right - left), height: trackHeight - selectionInset * 2)
            .padding(.vertical, selectionInset)
            .offset(x: left)
            .allowsHitTesting(false)
    }

    private func playhead(x: CGFloat) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.white)
                .frame(width: 3, height: trackHeight - 6)
                .padding(.vertical, 3)
                .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)

            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .offset(y: -(trackHeight / 2))
        }
        .offset(x: x - 1.5)
        .allowsHitTesting(false)
    }

    private func handle(isLeading: Bool, x: CGFloat, width: CGFloat) -> some View {
        let offsetX = x - handleWidth / 2
        let maxOffsetX = max(0, width - handleWidth)
        let clampedOffsetX = min(max(0, offsetX), maxOffsetX)
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.accentColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

            Rectangle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 2, height: 12)
        }
        .frame(width: handleWidth, height: trackHeight - 2)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .offset(x: clampedOffsetX)
        .zIndex(10)
        .accessibilityLabel(isLeading ? "Inicio" : "Fin")
    }

    private func beginDragIfNeeded() {
        guard dragState == nil else { return }
        dragState = DragState(initialStartSeconds: startSeconds, initialEndSeconds: endSeconds)
    }

    private func updateHandle(_ handle: DragHandle, translationX: CGFloat, width: CGFloat) {
        guard durationSeconds > 0, width > 0 else { return }
        guard let dragState else { return }

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
            stepSeconds: 0.1,
            minimumSelectionSeconds: 3,
            onScrub: { current = $0 },
            onBeginEditing: {}
        )
    }
}
