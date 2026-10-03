@testable import PeekOCR
import XCTest

final class ExportStallDetectorTests: XCTestCase {
    private let policy = ExportStallPolicy(sampleInterval: 0.5, minimumFramesPerSecond: 24, finishAllowance: 2)

    func testHealthyEncodeIsNeverStalled() {
        var detector = ExportStallDetector(policy: policy)
        for tick in 1...10 {
            XCTAssertFalse(detector.isStalled(at: Double(tick) * 0.5, appendedFrames: Int64(tick * 80)))
        }
    }

    func testStarvedEncodeIsStalledOnceTheQueuedFramesStopHidingIt() {
        var detector = ExportStallDetector(policy: policy)
        XCTAssertFalse(detector.isStalled(at: 0.5, appendedFrames: 20))
        XCTAssertTrue(detector.isStalled(at: 1.0, appendedFrames: 20))
    }

    func testTrickleBelowTheMinimumRateIsStalled() {
        var detector = ExportStallDetector(policy: policy)
        XCTAssertFalse(detector.isStalled(at: 0.5, appendedFrames: 28))
        XCTAssertTrue(detector.isStalled(at: 1.0, appendedFrames: 36))
    }

    func testWaitingForTheFirstFrameIsNotAStall() {
        var detector = ExportStallDetector(policy: policy)
        XCTAssertFalse(detector.isStalled(at: 0.5, appendedFrames: 0))
        XCTAssertFalse(detector.isStalled(at: 1.0, appendedFrames: 0))
        XCTAssertFalse(detector.isStalled(at: 1.5, appendedFrames: 90))
        XCTAssertFalse(detector.isStalled(at: 2.0, appendedFrames: 180))
    }

    func testFinishingGetsItsOwnAllowance() {
        var detector = ExportStallDetector(policy: policy)
        XCTAssertFalse(detector.isStalled(at: 0.5, appendedFrames: 100))
        detector.markFinishing(at: 0.6)
        XCTAssertFalse(detector.isStalled(at: 1.0, appendedFrames: 100))
        XCTAssertFalse(detector.isStalled(at: 2.5, appendedFrames: 100))
        XCTAssertTrue(detector.isStalled(at: 2.6, appendedFrames: 100))
    }
}
