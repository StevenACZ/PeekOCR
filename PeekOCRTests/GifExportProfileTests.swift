import XCTest

@testable import PeekOCR

final class GifExportProfileTests: XCTestCase {

    private func localizedString(_ key: String, language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    func testProfileDisplayNamesAreLocalizedInBothLanguages() throws {
        let expected: [GifExportProfile: (english: String, spanish: String)] = [
            .low: ("Low", "Baja"),
            .aiDebug: ("AI Debug", "AI Debug"),
            .high: ("High", "Alta"),
        ]

        for profile in GifExportProfile.allCases {
            let values = try XCTUnwrap(expected[profile])
            XCTAssertEqual(try localizedString(profile.localizationKey, language: "en"), values.english)
            XCTAssertEqual(try localizedString(profile.localizationKey, language: "es"), values.spanish)
            XCTAssertTrue([values.english, values.spanish].contains(profile.displayName))
        }
    }
}
