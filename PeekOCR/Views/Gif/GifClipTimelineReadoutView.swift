//
//  GifClipTimelineReadoutView.swift
//  PeekOCR
//
//  Readout row that displays In/Out timestamps and selected duration.
//

import SwiftUI

/// Readout shown under the timeline (In/Out and selected duration).
struct GifClipTimelineReadoutView: View {
    let startSeconds: Double
    let endSeconds: Double

    var body: some View {
        HStack(spacing: 16) {
            timeChip(label: "In", value: startSeconds)
            Spacer()
            durationBadge
            Spacer()
            timeChip(label: "Out", value: endSeconds)
        }
    }

    private func timeChip(label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(formatSeconds(value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var durationBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Selección")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(format(startSeconds: startSeconds, endSeconds: endSeconds))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func format(startSeconds: Double, endSeconds: Double) -> String {
        let duration = max(0, endSeconds - startSeconds)
        return formatSeconds(duration)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00.0" }
        let clamped = max(0, seconds)
        let minutes = Int(clamped / 60)
        let secs = clamped - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, secs)
    }
}

#Preview {
    GifClipTimelineReadoutView(startSeconds: 1.2, endSeconds: 5.4)
        .padding()
        .frame(width: 720)
}
