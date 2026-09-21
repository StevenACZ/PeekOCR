import AppKit
import SwiftUI
import XCTest

@testable import PeekOCR

final class ArrowGeometryTests: XCTestCase {
    func testTipDoesNotExtendPastEndpointAndTailIsRounded() {
        let path = ArrowGeometry.path(from: CGPoint(x: 20, y: 40), to: CGPoint(x: 100, y: 40), width: 8)
        XCTAssertEqual(path.boundingBoxOfPath.maxX, 100, accuracy: 0.001)
        XCTAssertEqual(path.boundingBoxOfPath.minX, 16, accuracy: 0.001)
        XCTAssertTrue(path.contains(CGPoint(x: 17, y: 40)))
        XCTAssertFalse(path.contains(CGPoint(x: 17, y: 43.5)))
        XCTAssertTrue(path.contains(CGPoint(x: 95, y: 40)))
        XCTAssertFalse(path.contains(CGPoint(x: 99, y: 42)))
    }

    func testShortArrowHeadStaysWithinDragAndRotatesWithEndpoints() {
        for length in [CGFloat(0.01), 1, 4, 12] {
            let path = ArrowGeometry.path(from: .zero, to: CGPoint(x: 0, y: length), width: 12)
            XCTAssertEqual(path.boundingBoxOfPath.maxY, length, accuracy: 0.0001)
            XCTAssertLessThan(path.boundingBoxOfPath.width, length)
            XCTAssertGreaterThan(path.boundingBoxOfPath.minY, -length * 0.25)
            XCTAssertTrue(path.contains(CGPoint(x: 0, y: length * 0.5)))
        }
        let reversed = ArrowGeometry.path(from: CGPoint(x: 100, y: 0), to: .zero, width: 8)
        XCTAssertEqual(reversed.boundingBoxOfPath.minX, 0, accuracy: 0.001)
        XCTAssertEqual(reversed.boundingBoxOfPath.maxX, 104, accuracy: 0.001)
    }

    func testDegenerateInputsProduceNoMark() {
        XCTAssertTrue(ArrowGeometry.path(from: .zero, to: .zero, width: 8).isEmpty)
        for width in [CGFloat.zero, -1, .infinity, .nan] {
            XCTAssertTrue(ArrowGeometry.path(from: .zero, to: CGPoint(x: 10, y: 10), width: width).isEmpty)
        }
        XCTAssertTrue(ArrowGeometry.path(from: CGPoint(x: CGFloat.nan, y: 0), to: .zero, width: 8).isEmpty)
    }

    func testExportHasNoTipOvershootOrDoubleOpacitySeam() throws {
        let context = try makeContext(size: 128)
        let annotation = LiveAnnotation(
            tool: .arrow, color: NSColor.red.withAlphaComponent(0.5),
            startPoint: CGPoint(x: 20, y: 64), endPoint: CGPoint(x: 100, y: 64), strokeWidth: 8)
        let output = try XCTUnwrap(
            LiveAnnotationRenderer.render(
                image: try XCTUnwrap(context.makeImage()),
                selectionRectInScreen: CGRect(x: 0, y: 0, width: 128, height: 128),
                scaleFactor: 1, annotations: [annotation]))
        context.draw(output, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        let alpha = try alphaBytes(context)
        XCTAssertEqual(alpha.max(), 128)
        for y in 0..<128 {
            for x in 100..<128 {
                XCTAssertEqual(alpha[y * 128 + x], 0)
            }
        }
    }

    func testLiveAndLegacyExportsAgreeAtRetinaAndStandardScale() throws {
        for scale in [CGFloat(1), 2] {
            let size = Int(128 * scale)
            let liveContext = try makeContext(size: size)
            let legacyContext = try makeContext(size: size)
            let color = NSColor.red.withAlphaComponent(0.5)
            let live = LiveAnnotation(
                tool: .arrow, color: color,
                startPoint: CGPoint(x: 220, y: 340), endPoint: CGPoint(x: 300, y: 380), strokeWidth: 8)
            let image = try XCTUnwrap(
                LiveAnnotationRenderer.render(
                    image: try XCTUnwrap(liveContext.makeImage()),
                    selectionRectInScreen: CGRect(x: 200, y: 300, width: 128, height: 128),
                    scaleFactor: scale, annotations: [live]))
            liveContext.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            let legacy = Annotation(
                tool: .arrow, color: Color(nsColor: color), strokeWidth: 8,
                startPoint: CGPoint(x: 20, y: 88), endPoint: CGPoint(x: 100, y: 48))
            CGContextAnnotationRenderer.render(
                annotations: [legacy], to: legacyContext,
                imageSize: CGSize(width: size, height: size), canvasSize: CGSize(width: 128, height: 128))
            XCTAssertEqual(try alphaBytes(liveContext), try alphaBytes(legacyContext))
        }
    }

    private func makeContext(size: Int) throws -> CGContext {
        try XCTUnwrap(
            CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
    }

    private func alphaBytes(_ context: CGContext) throws -> [UInt8] {
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<context.width * context.height).map { bytes[$0 * 4 + 3] }
    }
}
