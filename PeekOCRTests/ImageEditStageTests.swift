import AppKit
@testable import PeekOCR
import XCTest

@MainActor
final class ImageEditStageTests: XCTestCase {
    private let stageRect = CGRect(x: 100, y: 100, width: 200, height: 100)

    func testUntouchedImageIsReturnedAsIs() throws {
        let image = try makeImage()
        let stage = ImageEditStage(image: image, rectInScreen: stageRect)
        XCTAssertTrue(stage.render(selectionRectInScreen: stageRect, annotations: []) === image)
    }

    func testCropMapsScreenSelectionToImagePixels() throws {
        let stage = ImageEditStage(image: try makeImage(), rectInScreen: stageRect)
        let bottomHalf = CGRect(x: 150, y: 100, width: 100, height: 50)
        let cropped = try XCTUnwrap(stage.render(selectionRectInScreen: bottomHalf, annotations: []))
        XCTAssertEqual(cropped.width, 200)
        XCTAssertEqual(cropped.height, 100)
        XCTAssertEqual(try pixel(of: cropped, x: 100, y: 50), [0, 0, 255])

        let topHalf = bottomHalf.offsetBy(dx: 0, dy: 50)
        let top = try XCTUnwrap(stage.render(selectionRectInScreen: topHalf, annotations: []))
        XCTAssertEqual(try pixel(of: top, x: 100, y: 50), [255, 0, 0])
    }

    func testAnnotationsLandOnTheCroppedImage() throws {
        let stage = ImageEditStage(image: try makeImage(), rectInScreen: stageRect)
        let selection = CGRect(x: 150, y: 100, width: 100, height: 50)
        let highlight = LiveAnnotation(
            tool: .highlight, color: .green, startPoint: CGPoint(x: 160, y: 110), endPoint: CGPoint(x: 240, y: 140),
            strokeWidth: 4)
        let rendered = try XCTUnwrap(stage.render(selectionRectInScreen: selection, annotations: [highlight]))
        XCTAssertEqual(rendered.width, 200)
        XCTAssertEqual(rendered.height, 100)
        let edge = try pixel(of: rendered, x: 100, y: 20)
        XCTAssertGreaterThan(edge[1], 200)
        XCTAssertLessThan(edge[2], 60)
    }

    func testCropKeepsAnnotationsInPlaceAndInsideTheImage() throws {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = LiveAnnotationOverlayView(screen: try XCTUnwrap(NSScreen.main), mode: .annotate)
        window.contentView = view
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let stage = window.convertToScreen(CGRect(x: 50, y: 50, width: 600, height: 400))
        view.imageStage = ImageEditStage(image: try makeImage(), rectInScreen: stage)
        view.selectionRectInScreen = stage

        view.selectedTool = .arrow
        try drag(view, window: window, from: CGPoint(x: 100, y: 300), to: CGPoint(x: 220, y: 400))
        let drawn = view.annotations
        XCTAssertEqual(drawn.count, 1)

        try drag(view, window: window, from: CGPoint(x: 650, y: 50), to: CGPoint(x: 400, y: 200))
        XCTAssertEqual(view.selectionRectInScreen, window.convertToScreen(CGRect(x: 50, y: 200, width: 350, height: 250)))
        XCTAssertEqual(view.annotations, drawn)

        try drag(view, window: window, from: CGPoint(x: 50, y: 450), to: CGPoint(x: 0, y: 600))
        XCTAssertEqual(view.selectionRectInScreen, window.convertToScreen(CGRect(x: 50, y: 200, width: 350, height: 250)))

        try drag(view, window: window, from: CGPoint(x: 700, y: 500), to: CGPoint(x: 700, y: 500))
        XCTAssertEqual(view.selectionRectInScreen, stage)
        XCTAssertEqual(view.annotations, drawn)
    }

    func testEditedImageReplacesTheClipboardFile() throws {
        let asset = try XCTUnwrap(CaptureClipboardAsset.prepare(try makeImage(), savedURL: nil))
        defer { try? FileManager.default.removeItem(at: asset.url) }
        let cropped = try XCTUnwrap(try makeImage().cropping(to: CGRect(x: 0, y: 0, width: 120, height: 80)))
        let updated = try XCTUnwrap(asset.replacingImage(cropped, quality: 1))
        XCTAssertEqual(updated.id, asset.id)
        XCTAssertEqual(updated.url, asset.url)
        XCTAssertEqual(updated.thumbnail.width, 120)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(asset.url as CFURL, nil))
        let stored = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(stored.width, 120)
        XCTAssertEqual(stored.height, 80)
    }

    /// 400×200 px: top half red, bottom half blue.
    private func makeImage() throws -> CGImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 100, width: 400, height: 100))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 100))
        return try XCTUnwrap(context.makeImage())
    }

    private func pixel(of image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        return Array(bytes.prefix(3))
    }

    private func drag(_ view: LiveAnnotationOverlayView, window: NSWindow, from start: CGPoint, to end: CGPoint) throws {
        view.mouseDown(with: try event(.leftMouseDown, window: window, point: start))
        view.mouseDragged(with: try event(.leftMouseDragged, window: window, point: end))
        view.mouseUp(with: try event(.leftMouseUp, window: window, point: end))
    }

    private func event(_ type: NSEvent.EventType, window: NSWindow, point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
}
