//
//  RangeSlider.swift
//  PeekOCR
//
//  A dual-handle slider for selecting a numeric range.
//

import SwiftUI

/// A dual-handle slider for selecting a range within bounds.
struct RangeSlider: View {
    enum Handle {
        case lower
        case upper
    }

    @Binding var lowerValue: Double
    @Binding var upperValue: Double

    let bounds: ClosedRange<Double>
    let step: Double
    let minimumDistance: Double

    var onValueChange: ((Handle, Double) -> Void)?

    @State private var activeHandle: Handle?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                track
                selectionTrack(width: width)
                handleView(.lower, width: width)
                handleView(.upper, width: width)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .frame(height: 28)
        .onAppear {
            normalizeValues()
        }
        .onChange(of: lowerValue) { _ in normalizeValues() }
        .onChange(of: upperValue) { _ in normalizeValues() }
    }

    private var track: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 6)
            .padding(.horizontal, 8)
    }

    private func selectionTrack(width: CGFloat) -> some View {
        let lowerX = xPosition(for: lowerValue, width: width)
        let upperX = xPosition(for: upperValue, width: width)
        return Capsule()
            .fill(Color.blue.opacity(0.35))
            .frame(width: max(0, upperX - lowerX), height: 6)
            .offset(x: lowerX)
            .padding(.horizontal, 8)
            .allowsHitTesting(false)
    }

    private func handleView(_ handle: Handle, width: CGFloat) -> some View {
        let value = handle == .lower ? lowerValue : upperValue
        let x = xPosition(for: value, width: width)

        return Circle()
            .fill(.background)
            .overlay(Circle().stroke(Color.blue.opacity(0.8), lineWidth: 2))
            .frame(width: 18, height: 18)
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            .offset(x: x - 9, y: 0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        activeHandle = handle
                        update(handle: handle, x: gesture.location.x, width: width)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                    }
            )
            .accessibilityLabel(handle == .lower ? "Inicio" : "Fin")
            .accessibilityValue(Text(String(format: "%.1f", value)))
    }

    private func update(handle: Handle, x: CGFloat, width: CGFloat) {
        guard step > 0 else { return }
        let clampedX = min(max(0, x), width)
        let value = value(forX: clampedX, width: width)
        let steppedValue = snapToStep(value)

        switch handle {
        case .lower:
            let maxLower = upperValue - minimumDistance
            lowerValue = min(max(steppedValue, bounds.lowerBound), maxLower)
            onValueChange?(handle, lowerValue)
        case .upper:
            let minUpper = lowerValue + minimumDistance
            upperValue = max(min(steppedValue, bounds.upperBound), minUpper)
            onValueChange?(handle, upperValue)
        }
    }

    private func normalizeValues() {
        guard step > 0 else { return }
        lowerValue = min(max(snapToStep(lowerValue), bounds.lowerBound), bounds.upperBound)
        upperValue = min(max(snapToStep(upperValue), bounds.lowerBound), bounds.upperBound)

        if upperValue < lowerValue + minimumDistance {
            upperValue = min(bounds.upperBound, lowerValue + minimumDistance)
        }
        if lowerValue > upperValue - minimumDistance {
            lowerValue = max(bounds.lowerBound, upperValue - minimumDistance)
        }
    }

    private func snapToStep(_ value: Double) -> Double {
        let range = bounds.upperBound - bounds.lowerBound
        guard range > 0 else { return bounds.lowerBound }

        let normalized = (value - bounds.lowerBound) / step
        let snapped = (normalized).rounded() * step + bounds.lowerBound
        return snapped
    }

    private func xPosition(for value: Double, width: CGFloat) -> CGFloat {
        let range = bounds.upperBound - bounds.lowerBound
        guard range > 0 else { return 0 }
        let fraction = (value - bounds.lowerBound) / range
        return CGFloat(fraction) * width
    }

    private func value(forX x: CGFloat, width: CGFloat) -> Double {
        let range = bounds.upperBound - bounds.lowerBound
        guard range > 0, width > 0 else { return bounds.lowerBound }
        let fraction = Double(x / width)
        return bounds.lowerBound + (range * fraction)
    }
}

// MARK: - Preview

#Preview {
    RangeSliderPreviewWrapper()
}

private struct RangeSliderPreviewWrapper: View {
    @State private var lower = 2.0
    @State private var upper = 8.0

    var body: some View {
        RangeSlider(
            lowerValue: $lower,
            upperValue: $upper,
            bounds: 0...10,
            step: 0.1,
            minimumDistance: 3
        )
        .padding()
        .frame(width: 420)
    }
}
