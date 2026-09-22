import AVFoundation
import CoreGraphics

enum GifClipFilmstrip {
    static let frameCount = 16

    static func load(
        videoURL: URL, durationSeconds: Double, count: Int = frameCount,
        onFrame: @MainActor (Int, CGImage) -> Void
    ) async {
        guard durationSeconds > 0, count > 0 else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.2, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
        let times = (0..<count).map { index in
            CMTime(seconds: (Double(index) + 0.5) / Double(count) * durationSeconds, preferredTimescale: 600)
        }
        var index = 0
        for await result in generator.images(for: times) {
            guard !Task.isCancelled else { return }
            if let image = try? result.image { await onFrame(index, image) }
            index += 1
        }
    }
}
