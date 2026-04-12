//
//  AppDateFormatters.swift
//  PeekOCR
//
//  Shared date formatting helpers for filenames and relative history labels.
//

import Foundation

enum AppDateFormatters {
    nonisolated static func filenameTimestamp(from date: Date = Date()) -> String {
        componentsString(from: date, includeMilliseconds: false)
    }

    nonisolated static func highPrecisionFilenameTimestamp(from date: Date = Date()) -> String {
        componentsString(from: date, includeMilliseconds: true)
    }

    nonisolated static func relativeTimestamp(for date: Date, relativeTo referenceDate: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }

    nonisolated private static func componentsString(from date: Date, includeMilliseconds: Bool) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )

        let base = String(
            format: "%04d-%02d-%02d_%02d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )

        guard includeMilliseconds else {
            return base
        }

        let milliseconds = max(0, min(999, (components.nanosecond ?? 0) / 1_000_000))
        return "\(base)-\(String(format: "%03d", milliseconds))"
    }
}
