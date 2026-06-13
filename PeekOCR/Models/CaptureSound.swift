//
//  CaptureSound.swift
//  PeekOCR
//
//  Selectable capture feedback sounds: the bundled shutter or a system sound.
//

import Foundation

enum CaptureSound: String, CaseIterable, Identifiable {
    case shutter
    case tink
    case pop
    case glass
    case purr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shutter: return "Obturador"
        case .tink: return "Tink"
        case .pop: return "Pop"
        case .glass: return "Glass"
        case .purr: return "Purr"
        }
    }

    /// NSSound name for system sounds; nil for the bundled shutter asset.
    var systemSoundName: String? {
        switch self {
        case .shutter: return nil
        case .tink: return "Tink"
        case .pop: return "Pop"
        case .glass: return "Glass"
        case .purr: return "Purr"
        }
    }
}
