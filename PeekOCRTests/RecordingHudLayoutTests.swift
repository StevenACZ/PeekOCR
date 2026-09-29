import AppKit
@testable import PeekOCR
import XCTest

@MainActor
final class RecordingHudLayoutTests: XCTestCase {
    func testButtonsAreConcentricCirclesThatStayPutWhenPaused() {
        let hud = RecordingHudView(frame: .zero)
        hud.qualityText = "2K · 30 FPS · GIF"
        hud.frame = CGRect(origin: .zero, size: hud.fittingSize)
        hud.layoutSubtreeIfNeeded()
        let recordingFrames = buttonFrames(in: hud)

        hud.isPaused = true
        hud.layoutSubtreeIfNeeded()
        let pausedFrames = buttonFrames(in: hud)

        XCTAssertEqual(recordingFrames.count, 2)
        XCTAssertEqual(pausedFrames.count, 2)
        for (recording, paused) in zip(recordingFrames, pausedFrames) {
            XCTAssertEqual(recording.midX, paused.midX, accuracy: 0.5)
        }
        XCTAssertEqual(recordingFrames.last?.maxX ?? 0, hud.bounds.maxX - 5, accuracy: 0.5)
        for frame in recordingFrames {
            XCTAssertEqual(frame.width, 28, accuracy: 0.01)
            XCTAssertEqual(frame.height, 28, accuracy: 0.01)
            XCTAssertEqual(frame.midY, hud.bounds.midY, accuracy: 0.5)
        }
    }

    private func buttonFrames(in view: NSView) -> [CGRect] {
        var frames: [CGRect] = []
        for subview in view.subviews {
            if subview.accessibilityRole() == .button {
                frames.append(subview.convert(subview.bounds, to: view))
            }
            frames += buttonFrames(in: subview).map { subview.convert($0, to: view) }
        }
        return frames.sorted { $0.minX < $1.minX }
    }
}
