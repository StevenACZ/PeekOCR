//
//  SoundSettings.swift
//  PeekOCR
//
//  UserDefaults-backed settings for capture sound feedback.
//

import Foundation
import Combine

final class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let captureSoundEnabled = "captureSoundEnabled"
        static let captureSoundVolume = "captureSoundVolume"
    }

    struct Defaults {
        static let captureSoundEnabled = true
        static let captureSoundVolume: Double = 0.7
    }

    @Published var captureSoundEnabled: Bool {
        didSet { defaults.set(captureSoundEnabled, forKey: Keys.captureSoundEnabled) }
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
    }
}
