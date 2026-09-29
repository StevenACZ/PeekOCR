import AVFoundation
@testable import PeekOCR
import XCTest

final class VideoExportFrameRateTests: XCTestCase {
    func testExportKeepsRealDurationAtExactlyTheRequestedFps() async throws {
        let bursty = [0.0, 0.02, 0.05, 0.3, 0.31, 1.0, 1.4, 1.45, 1.9]
        let sources: [(name: String, times: [Double], requestedFps: Int)] = [
            ("24 fps", (0..<48).map { Double($0) / 24 }, 60),
            ("60 fps", (0..<120).map { Double($0) / 60 }, 30),
            ("variable", bursty, 60),
        ]
        for (name, times, requestedFps) in sources {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let source = directory.appendingPathComponent("source.mov")
            try await writeClip(to: source, times: times, duration: 2)

            let output = try await VideoExportService.shared.exportVideo(
                videoURL: source,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
                outputDirectory: directory,
                options: VideoExportOptions(resolution: .p720, fps: requestedFps, codec: .h264)
            )

            let tracks = try await AVURLAsset(url: output).loadTracks(withMediaType: .video)
            let track = try XCTUnwrap(tracks.first)
            let (nominalFps, timeRange) = try await track.load(.nominalFrameRate, .timeRange)
            XCTAssertEqual(Double(nominalFps), Double(requestedFps), accuracy: 0.5, "\(name) -> \(requestedFps)")
            XCTAssertEqual(timeRange.duration.seconds, 2, accuracy: 0.05, "\(name) -> \(requestedFps)")
        }
    }

    private func writeClip(to url: URL, times: [Double], duration: Double) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 64,
            ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for (index, time) in times.enumerated() {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            let pool = try XCTUnwrap(adaptor.pixelBufferPool)
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            let pixelBuffer = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            memset(
                CVPixelBufferGetBaseAddress(pixelBuffer), Int32(index * 5 % 256),
                CVPixelBufferGetDataSize(pixelBuffer))
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600)))
        }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
