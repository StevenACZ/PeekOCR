import AppKit
import XCTest

@testable import PeekOCR

@MainActor
final class CaptureClipboardAssetTests: XCTestCase {
    func testExportedClipBecomesAssetAndCopiesAsFileOnly() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PeekOCRTest_\(UUID().uuidString).gif")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = NSImage(size: NSSize(width: 40, height: 24), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let gif = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .gif, properties: [:]))
        try gif.write(to: url)

        let prepared = await CaptureClipboardAsset.prepare(clipURL: url)
        let asset = try XCTUnwrap(prepared)
        XCTAssertTrue(asset.isClip)
        XCTAssertEqual(asset.formatLabel, "GIF")
        XCTAssertEqual(asset.url, url)
        XCTAssertEqual(asset.thumbnail.width, 40)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PeekOCRTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(CaptureClipboardWriter.write([asset], to: pasteboard))
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(urls?.map(\.standardizedFileURL), [url.standardizedFileURL])
        XCTAssertNil(pasteboard.data(forType: .png))
    }

    func testMissingClipIsRejected() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("PeekOCRTest_missing.mp4")
        let asset = await CaptureClipboardAsset.prepare(clipURL: missing)
        XCTAssertNil(asset)
    }
}
