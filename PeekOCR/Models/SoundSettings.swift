//
//  SoundSettings.swift
//  PeekOCR
//
//  UserDefaults-backed settings for capture sound feedback.
//

import Combine
import Foundation

final class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let captureSoundEnabled = "captureSoundEnabled"
        static let captureSoundVolume = "captureSoundVolume"
        static let captureSound = "captureSound"
        static let ocrFeedbackEnabled = "ocrFeedbackEnabled"
    }

    struct Defaults {
        static let captureSoundEnabled = true
        static let captureSoundVolume: Double = 0.7
        static let captureSound: CaptureSound = .shutter
        static let ocrFeedbackEnabled = true
    }

    @Published var captureSoundEnabled: Bool {
        didSet { defaults.set(captureSoundEnabled, forKey: Keys.captureSoundEnabled) }
    }

    @Published var captureSound: CaptureSound {
        didSet { defaults.set(captureSound.rawValue, forKey: Keys.captureSound) }
    }

    @Published var ocrFeedbackEnabled: Bool {
        didSet { defaults.set(ocrFeedbackEnabled, forKey: Keys.ocrFeedbackEnabled) }
    }

    @Published var captureSoundVolume: Double {
        didSet {
            let clamped = min(1.0, max(0.0, captureSoundVolume))
            if clamped != captureSoundVolume {
                captureSoundVolume = clamped
                return
            }
            defaults.set(captureSoundVolume, forKey: Keys.captureSoundVolume)
        }
    }

    private init() {
        if defaults.object(forKey: Keys.captureSoundEnabled) != nil {
            self.captureSoundEnabled = defaults.bool(forKey: Keys.captureSoundEnabled)
        } else {
            self.captureSoundEnabled = Defaults.captureSoundEnabled
        }

        let savedVolume = defaults.double(forKey: Keys.captureSoundVolume)
        self.captureSoundVolume = savedVolume > 0 ? savedVolume : Defaults.captureSoundVolume

        self.captureSound =
            defaults.string(forKey: Keys.captureSound).flatMap(CaptureSound.init(rawValue:))
            ?? Defaults.captureSound

        if defaults.object(forKey: Keys.ocrFeedbackEnabled) != nil {
            self.ocrFeedbackEnabled = defaults.bool(forKey: Keys.ocrFeedbackEnabled)
        } else {
            self.ocrFeedbackEnabled = Defaults.ocrFeedbackEnabled
        }
    }
}
