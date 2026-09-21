import AppKit
import XCTest

@testable import PeekOCR

@MainActor
final class CaptureBatchTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testRapidCapturesRemainOrderedAndRemovalChangesBothCopyModes() {
        var batch = CaptureBatch()
        let ids = (0..<4).map { _ in UUID() }
        for (index, id) in ids.enumerated() {
            _ = batch.append(id, at: start.addingTimeInterval(Double(index)), clipboardChangeCount: 10)
            batch.didCopy(changeCount: 10)
        }
        batch.remove(ids[1])
        batch.remove(ids[3])
        XCTAssertEqual(batch.copiedIDs(grouped: true), [ids[0], ids[2]])
        XCTAssertEqual(batch.copiedIDs(grouped: false), [ids[2]])
    }

    func testTimeoutExternalCopyAndPasteEachBeginANewGroup() {
        for reason in 0..<3 {
            var batch = CaptureBatch()
            _ = batch.append(UUID(), at: start, clipboardChangeCount: 10)
            batch.didCopy(changeCount: 10)
            if reason == 2 { batch.didPaste() }
            let next = UUID()
            let continues = batch.append(
                next, at: start.addingTimeInterval(reason == 0 ? 16 : 1), clipboardChangeCount: reason == 1 ? 11 : 10)
            XCTAssertFalse(continues)
            XCTAssertEqual(batch.ids, [next])
        }
    }

    func testLongSelectionKeepsTheGroupButCancelDoesNotExtendIt() {
        var batch = CaptureBatch()
        let first = UUID()
        _ = batch.append(first, at: start, clipboardChangeCount: 10)
        batch.didCopy(changeCount: 10)
        batch.beginCapture(at: start.addingTimeInterval(2), clipboardChangeCount: 10)
        let second = UUID()
        XCTAssertTrue(batch.append(second, at: start.addingTimeInterval(30), clipboardChangeCount: 10))
        batch.beginCapture(at: start.addingTimeInterval(31), clipboardChangeCount: 10)
        batch.endCapture()
        XCTAssertFalse(batch.append(UUID(), at: start.addingTimeInterval(50), clipboardChangeCount: 10))
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
            return CaptureClipboardAsset(id: UUID(), url: url, thumbnail: image)
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
