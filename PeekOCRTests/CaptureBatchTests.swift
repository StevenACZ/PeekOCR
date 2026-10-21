import AppKit
@testable import PeekOCR
import XCTest

@MainActor
final class CaptureBatchTests: XCTestCase {
    func testRapidCapturesRemainOrderedAndRemovalChangesBothCopyModes() {
        var batch = CaptureBatch()
        let ids = (0..<4).map { _ in UUID() }
        for id in ids {
            _ = batch.append(id, clipboardChangeCount: 10)
            batch.didCopy(changeCount: 10)
        }
        batch.remove(ids[1])
        batch.remove(ids[3])
        XCTAssertEqual(batch.copiedIDs(grouped: true), [ids[0], ids[2]])
        XCTAssertEqual(batch.copiedIDs(grouped: false), [ids[2]])
    }

    func testLateCaptureJoinsTheGroupWhileItOwnsTheClipboard() {
        var batch = CaptureBatch()
        let first = UUID()
        _ = batch.append(first, clipboardChangeCount: 10)
        batch.didCopy(changeCount: 10)
        let late = UUID()
        XCTAssertTrue(batch.append(late, clipboardChangeCount: 10))
        XCTAssertEqual(batch.copiedIDs(grouped: true), [first, late])
    }

    func testExternalCopyAndPasteEachBeginANewGroup() {
        for pasted in [false, true] {
            var batch = CaptureBatch()
            _ = batch.append(UUID(), clipboardChangeCount: 10)
            batch.didCopy(changeCount: 10)
            if pasted { batch.didPaste() }
            let next = UUID()
            XCTAssertFalse(batch.append(next, clipboardChangeCount: pasted ? 10 : 11))
            XCTAssertEqual(batch.ids, [next])
        }
    }

    func testClipboardHoldsSeparateFilesAndSingleImageFallback() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 20, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let data = try XCTUnwrap(ImageEncodingService.encode(image, format: .png))
        let assets = try (0..<3).map { index in
            let url = directory.appendingPathComponent("image-\(index).png")
            try data.write(to: url)
            return CaptureClipboardAsset(id: UUID(), url: url, thumbnail: image, savedURL: nil)
        }
        XCTAssertTrue(CaptureClipboardWriter.write(assets, to: pasteboard))
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(urls, assets.map(\.url))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 3)
        XCTAssertEqual(pasteboard.string(forType: .string), assets.map { "'" + $0.url.path + "'" }.joined(separator: " "))
        XCTAssertTrue(CaptureClipboardWriter.write([assets[1]], to: pasteboard))
        XCTAssertEqual(pasteboard.data(forType: .png), data)
        XCTAssertTrue(NSImage.canInit(with: pasteboard))
    }

    func testThumbnailIsBoundedWithoutChangingFullResolutionFile() throws {
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 2400, height: 1600, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let asset = try XCTUnwrap(CaptureClipboardAsset.prepare(image, savedURL: nil))
        defer { try? FileManager.default.removeItem(at: asset.url) }
        XCTAssertEqual(asset.thumbnail.width, 600)
        XCTAssertEqual(asset.thumbnail.height, 400)
        let full = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: asset.url)))
        XCTAssertEqual(full.pixelsWide, 2400)
        XCTAssertEqual(full.pixelsHigh, 1600)
    }
}
