//
//  GifClipSettings.swift
//  PeekOCR
//
//  UserDefaults-backed settings for clip capture and export defaults.
//

import Combine
import Foundation

/// Export format for the clip editor.
enum ClipExportFormat: String, CaseIterable, Identifiable {
    case gif
    case video

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gif: return "GIF"
        case .video: return "Video"
        }
    }
}

/// Settings for clip capture + export defaults.
final class GifClipSettings: ObservableObject {
    static let shared = GifClipSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let maxDurationSeconds = "gifClipMaxDurationSeconds"
        static let durationLimitEnabled = "gifClipDurationLimitEnabled"
        static let defaultExportFormat = "gifClipDefaultExportFormat"

        static let recordingFps = "gifClipRecordingFps"
        static let recordingShowsCursor = "gifClipRecordingShowsCursor"
        static let recordingCapturesSystemAudio = "gifClipRecordingCapturesSystemAudio"

        static let gifProfile = "gifClipGifProfile"
        static let gifFps = "gifClipGifFps"
        static let gifLoopEnabled = "gifClipGifLoopEnabled"

        static let videoResolution = "gifClipVideoResolution"
        static let videoFps = "gifClipVideoFps"
        static let videoCodec = "gifClipVideoCodec"
    }

    struct Defaults {
        static let maxDurationSeconds = Constants.Gif.defaultMaxDurationSeconds
        static let durationLimitEnabled = true
        static let exportFormat: ClipExportFormat = .gif

        static let recordingFps = 30
        static let recordingShowsCursor = true
        static let recordingCapturesSystemAudio = false

        static let gifProfile: GifExportProfile = .high
        static let gifFps = 15
        static let gifLoopEnabled = true

        static let videoResolution: VideoExportResolution = .p1080
        static let videoFps = 30
        static let videoCodec: VideoExportCodec = .h264
    }

    // MARK: - Clip Duration

    @Published var maxDurationSeconds: Int {
        didSet {
            let clamped = min(Constants.Gif.maxDurationRange.upperBound, max(Constants.Gif.maxDurationRange.lowerBound, maxDurationSeconds))
            if clamped != maxDurationSeconds {
                maxDurationSeconds = clamped
                return
            }
            defaults.set(maxDurationSeconds, forKey: Keys.maxDurationSeconds)
        }
    }

    @Published var durationLimitEnabled: Bool {
        didSet { defaults.set(durationLimitEnabled, forKey: Keys.durationLimitEnabled) }
    }

    /// nil means "record until the user stops".
    var effectiveMaxDurationSeconds: Int? {
        durationLimitEnabled ? maxDurationSeconds : nil
    }

    // MARK: - Default Export Format

    @Published var defaultExportFormat: ClipExportFormat {
        didSet { defaults.set(defaultExportFormat.rawValue, forKey: Keys.defaultExportFormat) }
    }

    // MARK: - Recording

    @Published var recordingFps: Int {
        didSet {
            let clamped = min(60, max(1, recordingFps))
            if clamped != recordingFps {
                recordingFps = clamped
                return
            }
            defaults.set(recordingFps, forKey: Keys.recordingFps)
        }
    }

    @Published var recordingShowsCursor: Bool {
        didSet { defaults.set(recordingShowsCursor, forKey: Keys.recordingShowsCursor) }
    }

    @Published var recordingCapturesSystemAudio: Bool {
        didSet { defaults.set(recordingCapturesSystemAudio, forKey: Keys.recordingCapturesSystemAudio) }
    }

    // MARK: - GIF Defaults

    @Published var gifProfile: GifExportProfile {
        didSet { defaults.set(gifProfile.rawValue, forKey: Keys.gifProfile) }
    }

    @Published var gifFps: Int {
        didSet {
            let clamped = min(Constants.Gif.gifMaxFps, max(1, gifFps))
            if clamped != gifFps {
                gifFps = clamped
                return
            }
            defaults.set(gifFps, forKey: Keys.gifFps)
        }
    }

    @Published var gifLoopEnabled: Bool {
        didSet { defaults.set(gifLoopEnabled, forKey: Keys.gifLoopEnabled) }
    }

    // MARK: - Video Defaults

    @Published var videoResolution: VideoExportResolution {
        didSet { defaults.set(videoResolution.rawValue, forKey: Keys.videoResolution) }
    }

    @Published var videoFps: Int {
        didSet {
            let clamped = min(60, max(1, videoFps))
            if clamped != videoFps {
                videoFps = clamped
                return
            }
            defaults.set(videoFps, forKey: Keys.videoFps)
        }
    }

    @Published var videoCodec: VideoExportCodec {
        didSet { defaults.set(videoCodec.rawValue, forKey: Keys.videoCodec) }
    }

    // MARK: - Initialization

    private init() {
        let savedMaxDuration = defaults.integer(forKey: Keys.maxDurationSeconds)
        let rawMaxDuration = savedMaxDuration > 0 ? savedMaxDuration : Defaults.maxDurationSeconds
        self.maxDurationSeconds = min(
            Constants.Gif.maxDurationRange.upperBound, max(Constants.Gif.maxDurationRange.lowerBound, rawMaxDuration))

        if defaults.object(forKey: Keys.durationLimitEnabled) != nil {
            self.durationLimitEnabled = defaults.bool(forKey: Keys.durationLimitEnabled)
        } else {
            self.durationLimitEnabled = Defaults.durationLimitEnabled
        }

        if let raw = defaults.string(forKey: Keys.defaultExportFormat),
            let format = ClipExportFormat(rawValue: raw)
        {
            self.defaultExportFormat = format
        } else {
            self.defaultExportFormat = Defaults.exportFormat
        }

        let savedRecordingFps = defaults.integer(forKey: Keys.recordingFps)
        self.recordingFps = min(60, max(1, savedRecordingFps > 0 ? savedRecordingFps : Defaults.recordingFps))

        if defaults.object(forKey: Keys.recordingShowsCursor) != nil {
            self.recordingShowsCursor = defaults.bool(forKey: Keys.recordingShowsCursor)
        } else {
            self.recordingShowsCursor = Defaults.recordingShowsCursor
        }

        if defaults.object(forKey: Keys.recordingCapturesSystemAudio) != nil {
            self.recordingCapturesSystemAudio = defaults.bool(forKey: Keys.recordingCapturesSystemAudio)
        } else {
            self.recordingCapturesSystemAudio = Defaults.recordingCapturesSystemAudio
        }

        if let raw = defaults.string(forKey: Keys.gifProfile),
            let profile = GifExportProfile(rawValue: raw)
        {
            self.gifProfile = profile
        } else {
            self.gifProfile = Defaults.gifProfile
        }

        let savedGifFps = defaults.integer(forKey: Keys.gifFps)
        self.gifFps = min(Constants.Gif.gifMaxFps, max(1, savedGifFps > 0 ? savedGifFps : Defaults.gifFps))

        if defaults.object(forKey: Keys.gifLoopEnabled) != nil {
            self.gifLoopEnabled = defaults.bool(forKey: Keys.gifLoopEnabled)
        } else {
            self.gifLoopEnabled = Defaults.gifLoopEnabled
        }

        if let raw = defaults.string(forKey: Keys.videoResolution),
            let resolution = VideoExportResolution(rawValue: raw)
        {
            self.videoResolution = resolution
        } else {
            self.videoResolution = Defaults.videoResolution
        }

        let savedVideoFps = defaults.integer(forKey: Keys.videoFps)
        self.videoFps = min(60, max(1, savedVideoFps > 0 ? savedVideoFps : Defaults.videoFps))

        if let raw = defaults.string(forKey: Keys.videoCodec),
            let codec = VideoExportCodec(rawValue: raw)
        {
            self.videoCodec = codec
        } else {
            self.videoCodec = Defaults.videoCodec
        }
    }

    // MARK: - Helpers

    func makeDefaultGifOptions() -> GifExportOptions {
        var options = GifExportOptions()
        options.applyProfilePreset(gifProfile)
        options.fps = gifFps
        options.isLoopEnabled = gifLoopEnabled
        return options
    }

    func makeDefaultVideoOptions() -> VideoExportOptions {
        VideoExportOptions(
            resolution: videoResolution,
            fps: videoFps,
            codec: videoCodec
        )
    }
}
