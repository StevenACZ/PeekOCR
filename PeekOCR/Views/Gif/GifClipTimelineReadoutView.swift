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
        HStack {
            timeChip(label: "In:", value: startSeconds)
            Spacer()
            Text("Duración seleccionada: \(format(startSeconds: startSeconds, endSeconds: endSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            timeChip(label: "Out:", value: endSeconds)
        }
    }

    private func timeChip(label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatSeconds(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

