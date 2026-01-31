//
//  GifClipSettings.swift
//  PeekOCR
//
//  UserDefaults-backed settings for clip capture and export defaults.
//

import Foundation
import Combine

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
        static let defaultExportFormat = "gifClipDefaultExportFormat"

        static let gifProfile = "gifClipGifProfile"
        static let gifFps = "gifClipGifFps"
        static let gifLoopEnabled = "gifClipGifLoopEnabled"

        static let videoResolution = "gifClipVideoResolution"
        static let videoCodec = "gifClipVideoCodec"
    }

    struct Defaults {
        static let maxDurationSeconds = Constants.Gif.defaultMaxDurationSeconds
        static let exportFormat: ClipExportFormat = .gif

        static let gifProfile: GifExportProfile = .high
        static let gifFps = 15
        static let gifLoopEnabled = true

        static let videoResolution: VideoExportResolution = .p1080
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

    // MARK: - Default Export Format

    @Published var defaultExportFormat: ClipExportFormat {
        didSet { defaults.set(defaultExportFormat.rawValue, forKey: Keys.defaultExportFormat) }
    }

    // MARK: - GIF Defaults

    @Published var gifProfile: GifExportProfile {
        didSet { defaults.set(gifProfile.rawValue, forKey: Keys.gifProfile) }
    }

    @Published var gifFps: Int {
        didSet {
            let clamped = min(20, max(1, gifFps))
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

    @Published var videoCodec: VideoExportCodec {
        didSet { defaults.set(videoCodec.rawValue, forKey: Keys.videoCodec) }
    }

    // MARK: - Initialization

    private init() {
        let savedMaxDuration = defaults.integer(forKey: Keys.maxDurationSeconds)
        let rawMaxDuration = savedMaxDuration > 0 ? savedMaxDuration : Defaults.maxDurationSeconds
        self.maxDurationSeconds = min(Constants.Gif.maxDurationRange.upperBound, max(Constants.Gif.maxDurationRange.lowerBound, rawMaxDuration))

        if let raw = defaults.string(forKey: Keys.defaultExportFormat),
           let format = ClipExportFormat(rawValue: raw) {
            self.defaultExportFormat = format
        } else {
            self.defaultExportFormat = Defaults.exportFormat
        }

        if let raw = defaults.string(forKey: Keys.gifProfile),
           let profile = GifExportProfile(rawValue: raw) {
            self.gifProfile = profile
        } else {
            self.gifProfile = Defaults.gifProfile
        }

        let savedGifFps = defaults.integer(forKey: Keys.gifFps)
        self.gifFps = min(20, max(1, savedGifFps > 0 ? savedGifFps : Defaults.gifFps))

        if defaults.object(forKey: Keys.gifLoopEnabled) != nil {
            self.gifLoopEnabled = defaults.bool(forKey: Keys.gifLoopEnabled)
        } else {
            self.gifLoopEnabled = Defaults.gifLoopEnabled
        }

        if let raw = defaults.string(forKey: Keys.videoResolution),
           let resolution = VideoExportResolution(rawValue: raw) {
            self.videoResolution = resolution
        } else {
            self.videoResolution = Defaults.videoResolution
        }

        if let raw = defaults.string(forKey: Keys.videoCodec),
           let codec = VideoExportCodec(rawValue: raw) {
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
            fps: 30,
            codec: videoCodec
        )
    }
}
