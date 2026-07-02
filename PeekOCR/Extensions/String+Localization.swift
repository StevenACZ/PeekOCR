//
//  String+Localization.swift
//  PeekOCR
//
//  Sugar for Localizable lookups through the shared LocalizationManager.
//

import Foundation

nonisolated extension String {
    /// Localized string for this key using the app language.
    var localized: String {
        LocalizationManager.shared.localizedString(self)
    }

    /// Localized format string for this key with arguments.
    func localized(_ args: CVarArg...) -> String {
        LocalizationManager.shared.localizedString(self, arguments: args)
    }
}
