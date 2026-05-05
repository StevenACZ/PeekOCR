//
//  DisplayEnumerator.swift
//  PeekOCR
//
//  Enumerates active physical displays and maps them to NSScreen instances.
//

import AppKit
import CoreGraphics

enum DisplayEnumerator {
    /// Returns every non-mirrored active display paired with its NSScreen, if one exists.
    /// Filters out secondary members of a mirror set so we never draw duplicate overlays.
    static func activeScreens() -> [(displayID: CGDirectDisplayID, screen: NSScreen)] {
        let displayIDs = activeDisplayIDs()
        let screensByID = Dictionary(
            uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
                return (id, screen)
            })

        return displayIDs.compactMap { id in
            if let screen = screensByID[id] {
                return (displayID: id, screen: screen)
            }
            return nil
        }
    }

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        var actualCount: UInt32 = count
        guard CGGetActiveDisplayList(count, &ids, &actualCount) == .success else { return [] }

        let resolvedCount = Int(actualCount)
        let slice = ids.prefix(resolvedCount)

        // Drop mirror-set secondaries — CGDisplayMirrorsDisplay returns the primary,
        // or kCGNullDirectDisplay if this is the primary or not mirrored.
        return slice.filter { id in
            CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay
        }
    }
}
