//
//  ExportStallDetector.swift
//  PeekOCR
//
//  Tells a starved video encoder from a healthy one while an export runs.
//

import Foundation

/// Thresholds for declaring an encode stalled.
struct ExportStallPolicy: Equatable {
    var sampleInterval: TimeInterval = 0.5
    var minimumFramesPerSecond: Double = 24
    var finishAllowance: TimeInterval = 2
}

/// The hardware encoder is shared by every app and serves realtime sessions
/// first: while another app records or renders video, an export drops from
/// hundreds of frames per second to almost none.
struct ExportStallDetector {
    private let policy: ExportStallPolicy
    private var previous: (time: TimeInterval, frames: Int64)?
    private var finishStartedAt: TimeInterval?

    init(policy: ExportStallPolicy) {
        self.policy = policy
    }

    /// Call once every video frame has been handed to the writer.
    mutating func markFinishing(at time: TimeInterval) {
        finishStartedAt = finishStartedAt ?? time
    }

    mutating func isStalled(at time: TimeInterval, appendedFrames: Int64) -> Bool {
        if let finishStartedAt {
            return time - finishStartedAt >= policy.finishAllowance
        }
        guard appendedFrames > 0 else { return false }
        // The writer queues its first frames without encoding them, so the
        // window they land in says nothing about the encoder.
        guard let previous else {
            self.previous = (time, appendedFrames)
            return false
        }
        let elapsed = time - previous.time
        guard elapsed > 0 else { return false }
        self.previous = (time, appendedFrames)
        return Double(appendedFrames - previous.frames) / elapsed < policy.minimumFramesPerSecond
    }
}
